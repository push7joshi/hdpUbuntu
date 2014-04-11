#!/usr/bin/env bash

if [ $# != 2 ]; then
        echo "Script Usage: . ./MultiNodesOneClickStartUp.sh <Path to Java JDK Home> <Node Info Files>"
        return 0
fi


echo "*********************************************************************"
echo "Hadoop 0.20.203.0 Multinodes OneClick Startup."
echo "*********************************************************************"

dirname=`pwd`
hostname=`head -n 1 $2`
username=`whoami`
count=0
ports=9000
port[0]=9001
port[1]=9002
port[2]=9003
port[4]=9004

if [ ! -n "$HADOOP_HOME" ]; then
	echo "Setting HADOOP_HOME"
	echo "export HADOOP_HOME=$dirname" >> ~/.bashrc
	export HADOOP_HOME=$dirname
	source ~/.bashrc
	echo "HADOOP_HOME = $HADOOP_HOME"
	#bash
else
        export HADOOP_HOME=$dirname
	echo "HADOOP_HOME = $HADOOP_HOME"
fi

#echo $dirname
echo "Master IP/Hostname = $hostname"
echo "Slaves IP/Hostname = `cat $2`"
echo " "
echo "Username = $username"


# find four available ports
while [ $count -lt 4 ] && [ $ports -lt 65535 ];
do
	if [ ! -n "`netstat -an | grep $ports`" ]; then
		#echo "Port $ports is avaliable"
		port[$count]=$ports
		echo "Port ${port[$count]} is avaliable"
		let count=$count+1
		#let ports=$ports+1
	fi
	let ports=$ports+1
#echo $port
#let count=$count+1
#echo $count
done

if [ $count -lt 4 ]; then
	echo "all ports are busy, please rerun the script"
	return 0
fi

# replace the port and host name

# 1. set master and slaves
echo "set Master IP/Hostname"
sed -e 's|__hostname__|'$hostname'|' conf/masters_template > conf/masters
#cp the slaves ip/hostname information to conf/slaves
cp $2 conf/slaves

# 2. Set JAVE_HOME
echo "Set JAVA_HOME = $1"
sed -e 's|__JAVA_HOME__|'$1'|' conf/hadoop-env_template.sh > conf/hadoop-env.sh
# on each slaves
for line in `cat conf/slaves`;do
 #echo "Remove all files under /tmp/$username in $line"
 echo "copy conf/hadoop-env.sh to work node $line"
 #ssh $line "rm /tmp/$username/* -rf"
 scp conf/hadoop-env.sh $line:$HADOOP_HOME/conf/hadoop-env.sh
done


# 3. core-site.xml
sed -e 's|__hostname__|'$hostname'|' -e 's|__port0__|'${port[0]}'|' -e 's|__username__|'$username'|'  conf/core-site_template.xml  > conf/core-site.xml
# on each slaves
for line in `cat conf/slaves`;do
 #echo "Remove all files under /tmp/$username in $line"
 echo "copy conf/core-site.xml to work node $line"
 #ssh $line "rm /tmp/$username/* -rf"
 scp conf/core-site.xml $line:$HADOOP_HOME/conf/
done


# 4. hdfs-site.xml
sed -e 's|__hostname__|'$hostname'|' -e 's|__port1__|'${port[1]}'|' -e 's|__username__|'$username'|'  conf/hdfs-site_template.xml  > conf/hdfs-site.xml
for line in `cat conf/slaves`;do
 #echo "Remove all files under /tmp/$username in $line"
 echo "copy conf/hdfs-site.xml to work node $line"
 #ssh $line "rm /tmp/$username/* -rf"
 scp conf/hdfs-site.xml $line:$HADOOP_HOME/conf/
done



# 5. mapred-site.xml
sed -e 's|__hostname__|'$hostname'|' -e 's|__port2__|'${port[2]}'|' -e 's|__port3__|'${port[3]}'|' -e 's|__username__|'$username'|'  conf/mapred-site_template.xml  > conf/mapred-site.xml
for line in `cat conf/slaves`;do
 #echo "Remove all files under /tmp/$username in $line"
 echo "copy conf/mapred-site.xml to work node $line"
 #ssh $line "rm /tmp/$username/* -rf"
 scp conf/mapred-site.xml $line:$HADOOP_HOME/conf/
done


# stop hadoop daemons
bin/stop-all.sh

#clean up all the files under /tmp first
for line in `cat conf/masters`;do
 echo "Remove all files under /tmp/$username in $line"
 ssh $line "rm /tmp/$username/* -rf;  rm /tmp/hadoop-$username/* -rf; rm /tmp/Jetty* -rf; rm /tmp/hsperfdata_$username -rf;"
done

for line in `cat conf/slaves`;do
 echo "Remove all files under /tmp/$username in $line"
 #ssh $line "rm /tmp/$username/* -rf"
 ssh $line "rm /tmp/$username/* -rf;  rm /tmp/hadoop-$username/* -rf; rm /tmp/Jetty* -rf; rm /tmp/hsperfdata_$username -rf;"
done

sleep 2

# Starting hadoop

# 1. format file system
echo "bin/hadoop namenode -format"
bin/hadoop namenode -format

# 2. start hdfs and mapreduce daemon
echo "bin/start-all.sh"
bin/start-all.sh

startStatus=0
delayTime=4

while [ $startStatus -lt 10 ] 
do
if [ -n "`netstat -an | grep ${port[0]}`" ] && [ -n "`netstat -an | grep ${port[2]}`" ]; then
        echo "*************************************"
        echo "Hadoop has been started successfully."
        echo "*************************************"
        echo "Please use lynx $hostname:${port[1]} to see HDFS status"
        echo "Please use lynx $hostname:${port[3]} to see MapReduce Daemon status"
	let startStatus=11
else
	if [ $startStatus -lt 10 ]; then
	        echo "checking Hadoop status, retrying after $delayTime second......"
		sleep $delayTime
		let delayTime=$delayTime*2
		let startStatus+=1
	else
		let startStatus+=1

        echo "*********************************************************"
        echo "Fail to start Hadoop, clean up Hadoop files under /tmp/."
        echo "*********************************************************"
        # stop Hadoop Daemons
        bin/stop-all.sh
        #echo "Rm all files under /tmp/$username"
        #rm /tmp/$username/* -rf
        for line in `cat conf/masters`;do
                echo "Remove all files under /tmp/$username in $line"
                #ssh $line "rm /tmp/$username/* -rf"
                ssh $line "rm /tmp/$username/* -rf;  rm /tmp/hadoop-$username/* -rf; rm /tmp/Jetty* -rf; rm /tmp/hsperfdata_$username -rf;"
        done
        for line in `cat conf/slaves`;do
                echo "Remove all files under /tmp/$username in $line"
                #ssh $line "rm /tmp/$username/* -rf"
                ssh $line "rm /tmp/$username/* -rf;  rm /tmp/hadoop-$username/* -rf; rm /tmp/Jetty* -rf; rm /tmp/hsperfdata_$username -rf;"
        done

        echo "Please rerun the script"

		
	fi

fi
done


