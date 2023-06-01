# import base64
import json
# import requests

f = open('001.json', 'r')

r = f.read()
import time 

s = time.time()
for i in range(10000):
    res = json.loads(r)
e = time.time()
print(e-s)
print((e-s)/10000)


print("====================")
res = json.loads(r)

s = time.time()
for i in range(10000):
    json.dumps(res)
e = time.time()
print(e-s)
print((e-s)/10000)
print(1/((e-s)/10000))