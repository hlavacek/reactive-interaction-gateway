

```
JWT_SECRET_KEY=myJwtSecret mix phx.server
```





curl "localhost:4000/socket/sse?users\[\]=alice&token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE4OTM0NTYwMDAsImp0aSI6IjE1MjEyMjc0MjUiLCJyb2xlcyI6W10sInVzZXIiOiJhbGljZSJ9.r0usc_OgmowSo77fs4KXAz4cynkD2JcAiLEfDkF4aCA"

curl -H 'content-type: application/json' -d '{"user":"alice","text":"Hi, Alice!"}' localhost:4010/v1/messages
