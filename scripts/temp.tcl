set ns [new Simulator]

#
# Flow configurations
#

set workload "conga" ;# cachefollower, mining, search, webserver
set linkLoad 0.65 ;# ranges from 0.0 to 1.0

#
# Toplogy configurations
#
set linkRate 100 ;# Gb
set hostDelay 0.00 ;# secs
set linkDelayHostTor 0.000001 ;# secs
set linkDelayTorAggr 0.000001 ;# secs
set dataBufferHost [expr 50000*1538] ;# bytes / port
set dataBufferFromTorToAggr [expr 50000*1538] ;# bytes / port
set dataBufferFromAggrToTor [expr 50000*1538] ;# bytes / port
set dataBufferFromTorToHost [expr 50000*1538] ;# bytes / port

set numAggr 8 ;# number of aggregator switches
set numTor 8 ;# number of ToR switches
set numNode 128 ;# number of nodes

#
# XPass configurations
#
set alpha 0.5
set w_init 0.0625
set creditBuffer [expr 84*8]
set maxCreditBurst [expr 84*2]
set minJitter -0.1
set maxJitter 0.1
set minEthernetSize 84
set maxEthernetSize 1538
set minCreditSize 76
set maxCreditSize 92
set xpassHdrSize 78
set maxPayload [expr $maxEthernetSize-$xpassHdrSize]
set avgCreditSize [expr ($minCreditSize+$maxCreditSize)/2.0]
set creditBW [expr $linkRate*125000000*$avgCreditSize/($avgCreditSize+$maxEthernetSize)]
set creditBW [expr int($creditBW)]


#
# Simulation setup
#
set simStartTime 1.0
set simEndTime 1.05

#Incast Config
set createIncast 1
set fanIn 100
set IncastSize 200000
#Init config params
set numIncasts [expr int(($simEndTime-$simStartTime)*64*$linkRate*1000000000.0*0.05/($fanIn*$IncastSize*8.0))]
set IncastGap [expr double(($simEndTime-$simStartTime)/$numIncasts)]

# Output file
file mkdir "outputs"
set nt [open "outputs/trace.out" w]
set fct_out [open "outputs/fct.out" w]
set wst_out [open "outputs/waste.out" w]
puts $fct_out "Flow ID,Flow Size (bytes),Flow Completion Time (secs)"
puts $wst_out "Flow ID,Flow Size (bytes),Wasted Credit"
close $fct_out
close $wst_out

set flowfile [open flowfile.tr w]

proc finish {} {
  global ns nt flowfile
  $ns flush-trace
  close $nt
  close $flowfile
  puts "Simulation terminated successfully."
  exit 0
}
#$ns trace-all $nt

# Basic parameter settings
Agent/XPass set min_credit_size_ $minCreditSize
Agent/XPass set max_credit_size_ $maxCreditSize
Agent/XPass set min_ethernet_size_ $minEthernetSize
Agent/XPass set max_ethernet_size_ $maxEthernetSize
Agent/XPass set max_credit_rate_ $creditBW
Agent/XPass set alpha_ $alpha
Agent/XPass set target_loss_scaling_ 0.125
Agent/XPass set w_init_ $w_init
Agent/XPass set min_w_ 0.01
Agent/XPass set retransmit_timeout_ 0.0001
Agent/XPass set min_jitter_ $minJitter
Agent/XPass set max_jitter_ $maxJitter

Queue/XPassDropTail set credit_limit_ $creditBuffer
Queue/XPassDropTail set max_tokens_ $maxCreditBurst
Queue/XPassDropTail set token_refresh_rate_ $creditBW

DelayLink set avoidReordering_ true
$ns rtproto DV
Agent/rtProto/DV set advertInterval 10
Node set multiPath_ 1
Classifier/MultiPath set symmetric_ true
Classifier/MultiPath set nodetype_ 0

# Workloads setting
if {[string compare $workload "mining"] == 0} {
  set workloadPath "workloads/workload_mining.tcl"
  set avgFlowSize 7410212
} elseif {[string compare $workload "search"] == 0} {
  set workloadPath "workloads/workload_search.tcl"
  set avgFlowSize 1654275
} elseif {[string compare $workload "cachefollower"] == 0} {
  set workloadPath "workloads/workload_cachefollower.tcl"
  set avgFlowSize 701490
} elseif {[string compare $workload "webserver"] == 0} {
  set workloadPath "workloads/workload_webserver.tcl"
  set avgFlowSize 63735
} elseif {[string compare $workload "conga"] == 0} {
  set workloadPath "workloads/conga.tcl"
  set avgFlowSize 121849
} else {
  puts "Invalid workload: $workload"
  exit 0
}

if {$createIncast} {
  set linkLoad [expr $linkLoad-0.05]
}
set overSubscRatio [expr double($numNode/$numTor)/double($numTor/$numAggr)]
set lambda [expr ($numNode*$linkRate*1000000000*$linkLoad)/($avgFlowSize*8.0)]
set avgFlowInterval [expr 2.0/$lambda]
set numFlow [expr int(($simEndTime-$simStartTime)*1.0/$avgFlowInterval)]
puts "NumFlow $numFlow"
# Random number generators
set RNGFlowSize [new RNG]
$RNGFlowSize seed 61569011

set RNGFlowInterval [new RNG]
$RNGFlowInterval seed 94762103

set RNGSrcNodeId [new RNG]
$RNGSrcNodeId seed 17391005

set RNGDstNodeId [new RNG]
$RNGDstNodeId seed 35010256

set randomFlowSize [new RandomVariable/Empirical]
$randomFlowSize use-rng $RNGFlowSize
$randomFlowSize set interpolation_ 2
$randomFlowSize loadCDF $workloadPath

set stddev [expr $avgFlowInterval/2.0]
#set meanLn [expr ((log($avgFlowInterval)/2.303)-($sigma*$sigma/2.0))]
#puts "MeanLn $meanLn"

set randomFlowInterval [new RandomVariable/Exponential]
$randomFlowInterval use-rng $RNGFlowInterval
$randomFlowInterval set avg_ $avgFlowInterval
#$randomFlowInterval set std_ $stddev

set randomSrcNodeId [new RandomVariable/Uniform]
$randomSrcNodeId use-rng $RNGSrcNodeId
$randomSrcNodeId set min_ 0
$randomSrcNodeId set max_ $numNode

set randomDstNodeId [new RandomVariable/Uniform]
$randomDstNodeId use-rng $RNGDstNodeId
$randomDstNodeId set min_ 0
$randomDstNodeId set max_ $numNode

# Node
puts "Creating nodes..."
for {set i 0} {$i < $numNode} {incr i} {
  set dcNode($i) [$ns node]
  $dcNode($i) set nodetype_ 1
}
for {set i 0} {$i < $numTor} {incr i} {
  set dcTor($i) [$ns node]
  $dcTor($i) set nodetype_ 2
}
for {set i 0} {$i < $numAggr} {incr i} {
  set dcAggr($i) [$ns node]
  $dcAggr($i) set nodetype_ 3
}

# Link
puts "Creating links..."

for {set i 0} {$i < $numTor} {incr i} {
  set aggrIndex [expr $i/4*2]
  for {set j 0} {$j < $numAggr} {incr j} {
    $ns simplex-link $dcTor($i) $dcAggr($j) [set linkRate]Gb $linkDelayTorAggr XPassDropTail
    set link_tor_aggr [$ns link $dcTor($i) $dcAggr($j)]
    set queue_tor_aggr [$link_tor_aggr queue]
    $queue_tor_aggr set data_limit_ $dataBufferFromTorToAggr

    $ns simplex-link $dcAggr($j) $dcTor($i) [set linkRate]Gb $linkDelayTorAggr XPassDropTail
    set link_aggr_tor [$ns link $dcAggr($j) $dcTor($i)]
    set queue_aggr_tor [$link_aggr_tor queue]
    $queue_aggr_tor set data_limit_ $dataBufferFromAggrToTor
  }
}

for {set i 0} {$i < $numNode} {incr i} {
  set torIndex [expr $i/($numNode/$numTor)]
  puts "torIndex $torIndex"
  $ns simplex-link $dcNode($i) $dcTor($torIndex) [set linkRate]Gb [expr $linkDelayHostTor+$hostDelay] XPassDropTail
  set link_host_tor [$ns link $dcNode($i) $dcTor($torIndex)]
  set queue_host_tor [$link_host_tor queue]
  $queue_host_tor set data_limit_ $dataBufferHost

  $ns simplex-link $dcTor($torIndex) $dcNode($i) [set linkRate]Gb $linkDelayHostTor XPassDropTail
  set link_tor_host [$ns link $dcTor($torIndex) $dcNode($i)]
  set queue_tor_host [$link_tor_host queue]
  $queue_tor_host set data_limit_ $dataBufferFromTorToHost
}

puts "Creating agents and flows..."
for {set i 0} {$i < $numFlow} {incr i} {
  set src_nodeid [expr int([$randomSrcNodeId value])]
  set dst_nodeid [expr int([$randomDstNodeId value])]

  while {$src_nodeid == $dst_nodeid} {
#    set src_nodeid [expr int([$randomSrcNodeId value])]
    set dst_nodeid [expr int([$randomDstNodeId value])]
  }

  set sender($i) [new Agent/XPass]
  set receiver($i) [new Agent/XPass]

  $sender($i) set fid_ $i
  $sender($i) set host_id_ $src_nodeid
  $receiver($i) set fid_ $i
  $receiver($i) set host_id_ $dst_nodeid

  $ns attach-agent $dcNode($src_nodeid) $sender($i)
  $ns attach-agent $dcNode($dst_nodeid) $receiver($i)

  $ns connect $sender($i) $receiver($i)

  $ns at $simEndTime "$sender($i) close"
  $ns at $simEndTime "$receiver($i) close"

  set srcIndex($i) $src_nodeid
  set dstIndex($i) $dst_nodeid
}

if {$createIncast} {
puts "Creating Incasts"
for {set j 0} {$j < $numIncasts} {incr j} {
  #set src_nodeid [expr int([$randomSrcNodeId value])]
  set dst_nodeid [expr int([$randomDstNodeId value])]
	for {set k 0} {$k < $fanIn} {incr k} {
		set src_nodeid [expr int([$randomSrcNodeId value])]
  while {$src_nodeid == $dst_nodeid} {
   set src_nodeid [expr int([$randomSrcNodeId value])]
  #  set dst_nodeid [expr int([$randomDstNodeId value])]
  }

  set i [expr $numFlow + $k + ($j * $fanIn)]
  set sender($i) [new Agent/XPass]
  set receiver($i) [new Agent/XPass]
  $sender($i) set fid_ $i
  $sender($i) set host_id_ $src_nodeid
  $receiver($i) set fid_ $i
  $receiver($i) set host_id_ $dst_nodeid

  $ns attach-agent $dcNode($src_nodeid) $sender($i)
  $ns attach-agent $dcNode($dst_nodeid) $receiver($i)

  $ns connect $sender($i) $receiver($i)

  $ns at $simEndTime "$sender($i) close"
  $ns at $simEndTime "$receiver($i) close"

  set srcIndex($i) $src_nodeid
  set dstIndex($i) $dst_nodeid
}
}
}
set nextTime $simStartTime
set fidx 0

set fincastid $numFlow
set nextIncast [expr $nextTime+$IncastGap]
puts "numIncasts $numIncasts"
proc sendBytes {} {
  global ns random_flow_size nextTime sender fidx randomFlowSize randomFlowInterval numFlow srcIndex dstIndex flowfile fincastid IncastSize IncastGap numIncasts nextIncast fanIn createIncast simEndTime
 if {$nextTime < $simEndTime} {
  if {$createIncast} {
  if {$nextTime > $nextIncast} {
	  if {$fincastid < [expr $numFlow + ($numIncasts * $fanIn)]} {
		for {set k 0} {$k < $fanIn} {incr k} {
			if {$fincastid < [expr $numFlow + ($numIncasts * $fanIn)]} {
  puts $flowfile "$nextTime $srcIndex($fincastid) $dstIndex($fincastid) $IncastSize $fincastid"
  $ns at $nextTime "$sender($fincastid) advance-bytes $IncastSize"
			set fincastid [expr $fincastid+1]
	}
	}
	set nextIncast [expr $nextTime+$IncastGap]
	}
	}
}

  while {1} {
    set fsize [expr ceil([expr [$randomFlowSize value]])]
    if {$fsize > 0} {
      break;
    }
  }

  puts $flowfile "$nextTime $srcIndex($fidx) $dstIndex($fidx) $fsize $fidx"
  $ns at $nextTime "$sender($fidx) advance-bytes $fsize"

  set nextTime [expr $nextTime+[$randomFlowInterval value]]
  set fidx [expr $fidx+1]

  if {$fidx < $numFlow} {
    $ns at $nextTime "sendBytes"
  }
}
}

$ns at 0.0 "puts \"Simulation starts!\""
$ns at $nextTime "sendBytes"
$ns at [expr $simEndTime+0.01] "finish"
$ns run
