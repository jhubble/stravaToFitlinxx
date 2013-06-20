stravaToFitlinxx
================

Upload Strava bike workouts to fitlinxx

This will currently take the activity feed from Strava and upload to fitlinxx.

Currently it is a fairly manual proces:

1. Login to strava and got to Training -> My Activities.
2. Paste that content in a text file
3. Run this script

You will need a fitlinxx login and password in order to upload. Fitlinxx is usually smart enough to recognize that a time and date is the same and not repeat the upload.

Once the Strava API is available, it could be used instead to really automate the process.

Currently, it assumes all workouts are "easy" bike rides for purpose of calorie calculation and workout entry.
