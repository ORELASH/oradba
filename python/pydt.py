import pyarrow.parquet as pq
import s3fs

# נתיב לקובץ ה-Parquet שלך
path = "s3://my-analytics-bucket/data/events/2025-10-20/events.parquet"

# יצירת גישה ל-S3
fs = s3fs.S3FileSystem()

# קריאת הסכמה בלבד
dataset = pq.ParquetDataset(path, filesystem=fs)
schema = dataset.schema.to_arrow_schema()

# מיפוי טיפוסי PyArrow → Redshift
type_map = {
    "bool": "BOOLEAN",
    "int8": "SMALLINT",
    "int16": "SMALLINT",
    "int32": "INTEGER",
    "int64": "BIGINT",
    "uint8": "SMALLINT",
    "uint16": "INTEGER",
    "uint32": "BIGINT",
    "uint64": "BIGINT",
    "float16": "REAL",
    "float32": "REAL",
    "float64": "DOUBLE PRECISION",
    "string": "VARCHAR",
    "binary": "VARBYTE",
    "large_string": "VARCHAR",
    "timestamp[ns]": "TIMESTAMP",
    "timestamp[us]": "TIMESTAMP",
    "timestamp[ms]": "TIMESTAMP",
    "date32": "DATE",
    "date64": "DATE",
    "list<item: int64>": "SUPER",      # nested → SUPER
    "struct<...>": "SUPER",            # struct → SUPER
}

# הדפסה של הסכמה עם סוגי הנתונים
for field in schema:
    arrow_type = str(field.type)
    rs_type = type_map.get(arrow_type, "SUPER")  # ברירת מחדל
    print(f"{field.name}: {rs_type} ({arrow_type})")
