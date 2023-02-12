# Weewx Setup

A custom Weewx Docker image with a few modifications
- Setup to install interceptor and mqtt publishing
- Hack the interceptor to ignore the time provided by the weather station, and return the current time in the container 

My weather station occasionally sends the wrong time / date or drifts by too much, so when submitting data to Weather Underground etc there can be issues with the time being incorrect.

## Settings

Since we're overriding the time with the local time in the container, ensure you're setting the TZ environment variable to the correct timezone.

