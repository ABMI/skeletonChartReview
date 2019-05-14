##settings

createCohorts<-function(connectionDetails,
                        cdmDatabaseSchema,
                        cohortDatabaseSchema,
                        vocabularyDatabaseSchema = cdmDatabaseSchema,
                        cohortTable = "cohort",
                        oracleTempSchema,
                        outputFolder){
  if (!file.exists(outputFolder))
    dir.create(outputFolder)
  
  connection <- DatabaseConnector::connect(connectionDetails)

    # Create study cohort table structure:
  sql <- SqlRender::loadRenderTranslateSql(sqlFilename = "CreateCohortTable.sql",
                                           packageName = "skeletonChartReview",
                                           dbms = attr(connection, "dbms"),
                                           oracleTempSchema = oracleTempSchema,
                                           cohort_database_schema = cohortDatabaseSchema,
                                           cohort_table = cohortTable)
  DatabaseConnector::executeSql(connection, sql, progressBar = FALSE, reportOverallTime = FALSE)
  
  # Instantiate cohorts:
  pathToCsv <- system.file("settings", "CohortsToCreate.csv", package = "skeletonChartReview")
  cohortsToCreate <- read.csv(pathToCsv)
  for (i in 1:nrow(cohortsToCreate)) {
    writeLines(paste("Creating cohort:", cohortsToCreate$name[i]))
    sql <- SqlRender::loadRenderTranslateSql(sqlFilename = paste0(cohortsToCreate$name[i], ".sql"),
                                             packageName = "skeletonChartReview",
                                             dbms = attr(connection, "dbms"),
                                             oracleTempSchema = oracleTempSchema,
                                             cdm_database_schema = cdmDatabaseSchema,
                                             vocabulary_database_schema = vocabularyDatabaseSchema,
                                             
                                             target_database_schema = cohortDatabaseSchema,
                                             target_cohort_table = cohortTable,
                                             target_cohort_id = cohortsToCreate$cohortId[i])
    DatabaseConnector::executeSql(connection, sql)
  }
  
  # Fetch cohort counts:
  sql <- "SELECT cohort_definition_id, COUNT(*) AS count FROM @cohort_database_schema.@cohort_table GROUP BY cohort_definition_id"
  sql <- SqlRender::renderSql(sql,
                              cohort_database_schema = cohortDatabaseSchema,
                              cohort_table = cohortTable)$sql
  sql <- SqlRender::translateSql(sql, targetDialect = attr(connection, "dbms"))$sql
  counts <- DatabaseConnector::querySql(connection, sql)
  names(counts) <- SqlRender::snakeCaseToCamelCase(names(counts))
  counts <- merge(counts, data.frame(cohortDefinitionId = cohortsToCreate$cohortId,
                                     cohortName  = cohortsToCreate$name))
  write.csv(counts, file.path(outputFolder, "CohortCounts.csv"))
}






