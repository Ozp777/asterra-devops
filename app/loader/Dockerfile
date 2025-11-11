# Base: AWS Lambda Python 3.11
FROM public.ecr.aws/lambda/python:3.11

# System deps (psycopg2-binary wheels cover libpq; no GDAL here)
# If you later add GeoPandas for the "D. Packaging" bonus on another service,
# use a larger image with system libs (GDAL/GEOS/PROJ).

# Copy code
COPY handler.py ${LAMBDA_TASK_ROOT}

# Python deps
RUN pip install --no-cache-dir \
    boto3 \
    psycopg2-binary

# Handler
CMD ["handler.lambda_handler"]

