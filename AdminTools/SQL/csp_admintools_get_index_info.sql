
/****** Object:  StoredProcedure [dbo].[csp_admintools_get_index_info]    Script Date: 2014-08-13 13:03:35 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[csp_admintools_get_index_info]
	-- Add the parameters for the stored procedure here
	@@defrag_threshold AS INTEGER,
	@@retval AS NVARCHAR(MAX) OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	-- FLAG_EXTERNALACCESS --
	SET NOCOUNT ON;
	DECLARE @tblname NVARCHAR(64)
	DECLARE @params NVARCHAR(64)
	DECLARE @count INTEGER
	DECLARE @sql NVARCHAR(128)
	
	DECLARE @tmp TABLE
	(
		[tname] NVARCHAR(64),
		[indexname] NVARCHAR(64),
		[indextype] NVARCHAR(64),
		[avg_fragmentation] NVARCHAR(8),
		[recordcount] INTEGER
	)

	DECLARE cur CURSOR STATIC LOCAL FORWARD_ONLY FOR
		SELECT DISTINCT OBJECT_NAME(ind.OBJECT_ID) AS TableName
		FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, NULL) indexstats 
		INNER JOIN sys.indexes ind 
		INNER JOIN [table] t ON t.[name] = OBJECT_NAME(ind.object_id)
		ON ind.object_id = indexstats.object_id 
		AND ind.index_id = indexstats.index_id 
		WHERE indexstats.avg_fragmentation_in_percent >= @@defrag_threshold

	OPEN cur
	FETCH NEXT FROM cur INTO @tblname
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @sql = N'SELECT @count = COUNT(*) FROM [' + @tblname + N'] WHERE [status] = 0'
		EXEC sp_executesql @sql, N'@count INT OUT', @count OUT
		--EXECUTE sp_executesql @sql, @params, @tblname = @@tblname, @count = @@count OUT
		INSERT INTO @tmp
		SELECT	OBJECT_NAME(ind.OBJECT_ID) AS TableName,
				ind.name AS IndexName, 
				indexstats.index_type_desc AS IndexType, 
				CAST(indexstats.avg_fragmentation_in_percent AS NVARCHAR(8)),
				@count
		FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, NULL) indexstats 
		INNER JOIN sys.indexes ind 
		INNER JOIN [table] t ON t.[name] = OBJECT_NAME(ind.object_id)
		ON ind.object_id = indexstats.object_id 
		AND ind.index_id = indexstats.index_id 
		WHERE indexstats.avg_fragmentation_in_percent >= @@defrag_threshold
		AND OBJECT_NAME(ind.object_id) = @tblname
		FETCH NEXT FROM cur INTO @tblname
	END

	CLOSE cur
	DEALLOCATE cur

	SET @@retval = N'<indices>' + (SELECT TOP 10 * FROM @tmp i ORDER BY [avg_fragmentation] DESC FOR XML AUTO ) + N'</indices>'
	
END
