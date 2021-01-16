import os
import sys
import math
from numpy import sort
from numpy import array
filename = sys.argv[1]
trfile = sys.argv[2]

start_times = {}
same_switch = {}


tracefile = open(trfile, 'r')
filedata = ''
for input in tracefile:
	filedata += input

filedata = filedata.split('\n')
for i in range(len(filedata)-1):
	#print(filedata[i])
	elements = filedata[i].split(' ')
	flowid = int(elements[4])
	starttime = float(elements[0])
	src = int(int(elements[1])/16)
	dst = int(int(elements[2])/16)
	start_times[flowid] = starttime
	same_switch[flowid] = (src == dst)

###
###

datarate = 100.0
Incast_size = 200000

tfile = open(filename, 'r')
filedata = ''
for input in tfile:
	filedata += input

filedata = filedata.split('\n')
arr = []
started = 0
finished = 0
failed = 0
completed =0
for i in range(1,len(filedata)-1):
	try:
		flowdata = filedata[i].split(',')
		flowid = int(flowdata[0])
		flowsize = int(flowdata[1])
		np = 1
		ps = flowsize
		fid = int(flowdata[0])
		if flowsize > 1000:
			np = int(flowsize/1000)+1
			ps = 1000
		base_time = 0.0
		ntime = (float(flowdata[2])- start_times[flowid])*1000000
		if same_switch[flowid]:
			base_time = 4.0 + (ps*8.0/(datarate*1000.0))*(np+1)
			ntime = ntime - 2.0
		else:
			base_time = 8.0 + (ps*8.0/(datarate*1000.0))*(np+3)
			ntime = ntime - 4.0
		ratio = ntime/base_time
		if flowsize == Incast_size:
			arr.append([-1,ntime, ratio])
		else:
			arr.append([np,ntime, ratio])
	except:
		continue

n = 10
nums = [0.0 for _ in range(n)]
sums = [0.0 for _ in range(n)]
maxims = [0.0 for _ in range(n)]
medians = [0.0 for _ in range(n)]
avgs = [0.0 for _ in range(n)]
percentiles = [0.0 for _ in range(n)]
percentiles_95 = [0.0 for _ in range(n)]
vals = [[] for _ in range(n)]

for i in range(len(arr)):
	j = -1
	if True:
		if arr[i][0]==-1:
			j = 9
		elif arr[i][0] <= 3:
			j = 0
		elif arr[i][0] <= 12:
			j = 1
		elif arr[i][0] <= 48:
			j = 2
		elif arr[i][0] <= 192:
			j = 3
		elif arr[i][0] <= 768:
			j = 4
		elif arr[i][0] <= 3072:
			j = 5
		elif arr[i][0] <= 12288:
			j = 6
		elif arr[i][0] <= 49152:
			j = 7
		else:
			j = 8

	else:
		if arr[i][0]==-1:
			j = 9
		elif arr[i][0] <= 1:
			j = 0
		elif arr[i][0] <= 2:
			j = 1
		elif arr[i][0] <= 4:
			j = 2
		elif arr[i][0] <= 8:
			j = 3
		elif arr[i][0] <= 16:
			j = 4
		elif arr[i][0] <= 64:
			j = 5
		elif arr[i][0] <= 256:
			j = 6
		elif arr[i][0] <= 1024:
			j = 7
		else:
			j = 8		
	nums[j] +=1
	sums[j] +=arr[i][2]
	vals[j].append(arr[i][2])
	# if arr[i][2] >= 10000:
	# 	print(j)
	# 	print(arr[i][1])
	# 	print("-----")

for i in range(len(medians)):
	if nums[i] != 0:
		s = sort(array(vals[i]))
		percentiles[i] = s[int(99.0/100.0*nums[i])]
		percentiles_95[i] = s[int(95.0/100.0*nums[i])]
		medians[i] = s[int(nums[i]/2)]
		avgs[i] = sums[i]/nums[i]
		maxims[i] = s[int(nums[i]-1)]
		#print(s)
		# print(len(s))



print("nums =", end=" ")
print(nums)
print("averages =", end=" ")
print(avgs)
print("medians =", end = " ")
print(medians)
print("95 percentile =", end=" ")
print(percentiles_95)
print("99 percentile =", end=" ")
print(percentiles)
print("Maximum =", end=" ")
print(maxims)

	



