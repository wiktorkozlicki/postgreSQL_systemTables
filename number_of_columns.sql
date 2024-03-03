SELECT TABLE_NAME,
  COUNT(*) AS NUMBER_OF_COLUMNS
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA LIKE 'public'
GROUP BY TABLE_NAME
ORDER BY NUMBER_OF_COLUMNS DESC;
