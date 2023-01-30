/***************************
      Bucket
    do NOT specify
  buckets, prefix, etc.
They must be passed on command line
  ***************************/
terraform {
  backend "gcs" {
  }
}