import json
import os
import logging
import boto3
import psycopg2
from psycopg2.extras import Json

logger = logging.getLogger()
logger.setLevel(logging.INFO)

DB_HOST = os.environ["DB_HOST"]
DB_PORT = int(os.environ.get("DB_PORT", "5432"))
DB_NAME = os.environ["DB_NAME"]
DB_USER = os.environ["DB_USER"]
DB_PASS = os.environ["DB_PASS"]

s3 = boto3.client("s3")

def _connect():
    return psycopg2.connect(
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME,
        user=DB_USER, password=DB_PASS, sslmode="require"
    )

def _ensure_postgis(conn):
    with conn.cursor() as cur:
        cur.execute("CREATE EXTENSION IF NOT EXISTS postgis;")
    conn.commit()

def _ensure_table(conn):
    with conn.cursor() as cur:
        cur.execute("""
        CREATE TABLE IF NOT EXISTS geo_features (
          id SERIAL PRIMARY KEY,
          name TEXT,
          properties JSONB,
          geom geometry(Geometry, 4326)
        );
        """)
    conn.commit()

def _load_geojson_to_db(conn, gj):
    feats = []
    if gj.get("type") == "FeatureCollection":
        feats = gj.get("features", [])
    elif gj.get("type") == "Feature":
        feats = [gj]
    else:
        raise ValueError("Unsupported GeoJSON type")

    inserted = 0
    with conn.cursor() as cur:
        for f in feats:
            geom = f.get("geometry")
            props = f.get("properties", {})
            name  = props.get("name") or f.get("id") or "unnamed"
            if not geom or "type" not in geom or "coordinates" not in geom:
                logger.warning("Skipping invalid/empty geometry")
                continue
            cur.execute(
                """
                INSERT INTO geo_features (name, properties, geom)
                VALUES (%s, %s, ST_SetSRID(ST_GeomFromGeoJSON(%s), 4326))
                """,
                (name, Json(props), json.dumps(geom))
            )
            inserted += 1
    conn.commit()
    return inserted

def lambda_handler(event, context):
    logger.info("Event: %s", json.dumps(event))
    for rec in event.get("Records", []):
        bucket = rec["s3"]["bucket"]["name"]
        key    = rec["s3"]["object"]["key"]
        if not key.endswith(".geojson"):
            logger.info("Skipping non-geojson key: %s", key)
            continue

        obj = s3.get_object(Bucket=bucket, Key=key)
        body = obj["Body"].read()
        if len(body) > 25 * 1024 * 1024:
            raise ValueError("File too large (>25MB)")

        gj = json.loads(body.decode("utf-8"))

        conn = _connect()
        try:
            _ensure_postgis(conn)
            _ensure_table(conn)
            inserted = _load_geojson_to_db(conn, gj)
            logger.info("Inserted %d features from s3://%s/%s", inserted, bucket, key)
        finally:
            conn.close()

    return {"status": "ok"}
