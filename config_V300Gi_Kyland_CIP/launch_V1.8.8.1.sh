#!/bin/bash
##################################################################################################
# Copyright (C) 2013-2033 by NAURA
# File: launch.sh
# Date: 2018-04-27
# Author: zhangl, <zhanglu01@naura.com>
# Version: 1.5
# Descriptor: launch MEC program
# Modified: 2013-11-11 zhangl create
#           2018-04-27 yangy add auto reboot mec
#           2020-09-24 fuml modify option for single item
#                      support custom demo path
#           2022-07-28 songxl modified, nohub mode but read result from syslog
#           2022-08-24 songxl modified, suport chinese
#           2022-09-02 songxl modified, print more error messages
#           2024-01-08 chengyf modified, Auto obtain REBUILT and SIMULATE config
#           2025-04-02 xsm modified, merge launch.sh for keshi, PVD and CVD
#           2025-04-24 xsm modified, generate singular version 1.7.5 for keshi 
#           2025-04-27 xsm modified, auto APPNAME, add APPExitTime, add taskset, change nohup to setsid to avoid terminal close
#           2025-05-15 xsm modified，abandon output of debugger，match Mems|LED|PECVD，change restart time to 60s, change showLog function
#           2025-05-20 xsm modified，adapted to ProtectEtch
#           2025-06-10 xsm modified, change nproc to lscpu, change coredump location for redhat, add loginctl command
##################################################################################################

### need modify

# language of echo message Chinese or English
LangEchoMsg=Chinese
# launchVersion
LaunchVersion=1.8
# y for taskset -c 1-3
isTaskset=y
# time for kill -15
APPExitTime=30



# All DeviceNets of PVD Tool
MEC_DeviceNetList=(
#Platform
Ch1
Ch2
Ch3
Ch4
Ch5
Ch6
ChE
ChF
PM1
PM2
PM3
PM4
PM5
PM6
DxA
DxB
#LoadRack
) 

# All Modules of PVD Tool
MEC_ModuleList=(
#Platform 
Ch1
Ch2
Ch3
Ch4
Ch5
Ch6
Ch7
Ch8
ChA
ChB
ChC
ChD
ChE
ChF
PM1
PM2
PM3
PM4 
PM5
PM6
DxA
DxB
LA
LB
Transfer
Buffer
#System
) 
##

function AutoObtainCfg(){    # Auto obtain REBUILT and SIMULATE config
    cd $CONFIGHOME/Control   

    start1="<\!--"
    end1="-->"
    start2="<\!\[CDATA\["
    end2="\]\]>"
    #result=$(sed -n "s/.*$start\(.*\)$end.*/\1/p"  Control_config.xml;)  
    #sed -n "s/.*<\!--\(.*\)-->.*/\1/p"  Control_config.xml>$temp_file  #将文件中“<--”和“-->”之间的字符存入临时文件temp_file
    #temp_file_line=$(wc -l < $temp_file)   #获取文件行数
    temp_file="temp_chengyf.txt"
    grep -Po "(?s)$start1.*?$end1" "Control_config.xml" >$temp_file  
    grep -Po "(?s)$start2.*?$end2" "Control_config.xml" >>$temp_file  
    grep -Pzo "(?s)$start1.*?$end1" "Control_config.xml" >>$temp_file    #将文件中start和end之间的字符存入临时文件temp_file
    grep -Pzo "(?s)$start2.*?$end2" "Control_config.xml" >>$temp_file  

    CDN=()
    CDN=$(grep -E "&Ctrl_|&Control_" $temp_file)  #提取文件中包含&Ctrl_的行存入CDN数组

    temp_file_LC="tempLC_chengyf.txt"
    grep -Po "(?s)$start1.*?$end1" "$CONFIGHOME/Driver_config.xml" >$temp_file_LC  
    grep -Po "(?s)$start2.*?$end2" "$CONFIGHOME/Driver_config.xml" >>$temp_file_LC  
    grep -Pzo "(?s)$start1.*?$end1" "$CONFIGHOME/Driver_config.xml" >>$temp_file_LC    
    grep -Pzo "(?s)$start2.*?$end2" "$CONFIGHOME/Driver_config.xml" >>$temp_file_LC  


    temp_file_check="tempcheck_chengyf.txt"
    temp_file_check1="tempcheck1_chengyf.txt"	
    grep -i "addDeviceNode" $temp_file>$temp_file_check
    grep -i "addDeviceNode" Control_config.xml>$temp_file_check1
    #CND_CH=$(awk -F '_' '{print $2}' ${CDN[$i]})
    #IFS="_"   #将分割符设置为“;”
    #read -ra CND_CH <<< "${CDN[0]}"  #read -r:读取输入内容  -a:将输入分割成数组

    ###########REBUILT############
    for ((i=0; i<${#MEC_DeviceNetList[*]};i++)) ;do
        grep -Esq "&Ctrl_${MEC_DeviceNetList[$i]}|&Control_${MEC_DeviceNetList[$i]}" Control_config.xml;
        rm=$?  
        if [ "$rm" == "0" ]; then
            if [[ "$CDN" =~ "&Ctrl_${MEC_DeviceNetList[$i]}"  ]]; then 
                grep -sq "${MEC_DeviceNetList[$i]}" $temp_file_check1; 	
                ck1=$?	
                if [ "$ck1" == "0" ]; then		
                    grep -sq "${MEC_DeviceNetList[$i]}" $temp_file_check;  #解决注释问题：ChX既有注释掉，也包含没有注释掉内容，在addDeviceNode做二次check
                    ck=$?
                    if [ "$ck" == "0" ]; then
                        echo "" #包含注释掉的内容，则不作任何操作
                    else
                        MEC_DN=(${MEC_DN[*]} ${MEC_DeviceNetList[$i]})
                    fi
                else
                    echo ""
                fi
            elif [[ "$CDN" =~ "&Control_${MEC_DeviceNetList[$i]}"  ]]; then
                grep -sq "${MEC_DeviceNetList[$i]}" $temp_file_check1; 	
                ck1=$?	
                if [ "$ck1" == "0" ]; then					
                    grep -sq "${MEC_DeviceNetList[$i]}" $temp_file_check; 
                    ck=$?
                    if [ "$ck" == "0" ]; then
                        echo "" #包含注释掉的内容，则不作任何操作
                    else
                        MEC_DN=(${MEC_DN[*]} ${MEC_DeviceNetList[$i]})
                    fi
                else
                    echo ""
                fi					
            else
                MEC_DN=(${MEC_DN[*]} ${MEC_DeviceNetList[$i]})
            fi
        fi
    done       

    grep -sq "&Driver_LoadCenter" $CONFIGHOME/Driver_config.xml; 
    lc=$?                        
    if [ "$lc" == "0" ]; then
        grep -sq "&Driver_LoadCenter" $temp_file_LC;
        rml=$?  
        if [ "$rml" == "0" ]; then
            grep -sq "LoadCenter" $temp_file_check; 
            ck=$?
            if [ "$ck" == "0" ]; then
                MEC_DNL=("${MEC_DN[@]}" Platform LoadRack)   
            else
                MEC_DNL=("${MEC_DN[@]}" Platform LoadCenter)
            fi
        else
            MEC_DNL=("${MEC_DN[@]}" Platform LoadCenter)
        fi
    else
        MEC_DNL=("${MEC_DN[@]}" Platform LoadRack)
    fi

    grep -sq "&Driver_ChC" $CONFIGHOME/Driver_config.xml; 
    chc=$?                        
    if [ "$chc" == "0" ]; then
        grep -sq "&Driver_ChC" $temp_file_LC;
        rmc=$?  
        if [ "$rmc" == "0" ]; then
            grep -sq "ChC" $temp_file_check1; 	
            ck1=$?	
            if [ "$ck1" == "0" ]; then				
                grep -sq "ChC" $temp_file_check; 
                ck=$?
                if [ "$ck" == "0" ]; then
                    MEC_DNC=("${MEC_DNL[@]}")   
                else
                    MEC_DNC=("${MEC_DNL[@]}" ChC)
                fi
		    else
                MEC_DNC=("${MEC_DNL[@]}")   			
            fi
        else
            MEC_DNC=("${MEC_DNL[@]}" ChC)
        fi
    else
        MEC_DNC=("${MEC_DNL[@]}")
    fi

    grep -sq "&Driver_ChD" $CONFIGHOME/Driver_config.xml; 
    chd=$?                        
    if [ "$chd" == "0" ]; then
        grep -sq "&Driver_ChD" $temp_file_LC;
        rmd=$?  
        if [ "$rmd" == "0" ]; then
            grep -sq "ChD" $temp_file_check1; 	
            ck1=$?	
            if [ "$ck1" == "0" ]; then				
                grep -sq "ChD" $temp_file_check; 
                ck=$?
                if [ "$ck" == "0" ]; then
                    MEC_DeviceNet=("${MEC_DNC[@]}")   
                else
                    MEC_DeviceNet=("${MEC_DNC[@]}" ChD)
                fi
		    else
                MEC_DeviceNet=("${MEC_DNC[@]}")   			
            fi
        else
            MEC_DeviceNet=("${MEC_DNC[@]}" ChD)
        fi
    else
        MEC_DeviceNet=("${MEC_DNC[@]}")
    fi

    ###########SIMULATE############
    for ((i=0; i<${#MEC_ModuleList[*]};i++)) ;do
        grep -Esq "&Ctrl_${MEC_ModuleList[$i]}|&Control_${MEC_ModuleList[$i]}" Control_config.xml;
        rm=$?  
        if [ "$rm" == "0" ]; then
            if [[ "$CDN" =~ "&Ctrl_${MEC_ModuleList[$i]}"  ]]; then   
                grep -sq "${MEC_ModuleList[$i]}" $temp_file_check; 
                ck=$?
                if [ "$ck" == "0" ]; then
                    echo "" #包含注释掉的内容，则不作任何操作
                else
                    MEC_MD=(${MEC_MD[*]} ${MEC_ModuleList[$i]})
                fi
            elif [[ "$CDN" =~ "&Control_${MEC_ModuleList[$i]}"  ]]; then
                grep -sq "${MEC_ModuleList[$i]}" $temp_file_check; 
                ck=$?
                if [ "$ck" == "0" ]; then
                    echo "" #包含注释掉的内容，则不作任何操作
                else
                    MEC_MD=(${MEC_MD[*]} ${MEC_ModuleList[$i]})
                fi
            else
                MEC_MD=(${MEC_MD[*]} ${MEC_ModuleList[$i]})
            fi
        fi
    done       

    grep -sq "&Driver_LoadCenter" $CONFIGHOME/Driver_config.xml; 
    lc=$?                        
    if [ "$lc" == "0" ]; then
        grep -sq "&Driver_LoadCenter" $temp_file_LC;
        rml=$?  
        if [ "$rml" == "0" ]; then
            grep -sq "LoadCenter" $temp_file_check; 
            ck=$?
            if [ "$ck" == "0" ]; then
                grep -rsq "&SimulatedFlag_LoadRack" $CONFIGHOME; 
                lr=$?                        
                if [ "$lr" == "0" ]; then
                    MEC_MOD=("${MEC_MD[@]}" Platform System LoadRack)  
                else
                    MEC_MOD=("${MEC_MD[@]}" Platform System)  
                fi
            else
                MEC_MOD=("${MEC_MD[@]}" Platform System LoadCenter)
            fi     
        else
            MEC_MOD=("${MEC_MD[@]}" Platform System LoadCenter)
        fi
    else
        grep -rsq "&SimulatedFlag_LoadRack" $CONFIGHOME; 
        lr=$?                        
        if [ "$lr" == "0" ]; then
            MEC_MOD=("${MEC_MD[@]}" Platform System LoadRack)  
        else
            MEC_MOD=("${MEC_MD[@]}" Platform System)  
        fi
    fi

    grep -rsq "&SimulatedFlag_Motor" $CONFIGHOME; 
    mt=$?                        
    if [ "$mt" == "0" ]; then
        MEC_MOD1=("${MEC_MOD[@]}" Motor)
    else
        MEC_MOD1=("${MEC_MOD[@]}")
    fi

    grep -rsq "&SimulatedFlag_Fake" $CONFIGHOME; 
    fk=$?                        
    if [ "$fk" == "0" ]; then
        MEC_Module=("${MEC_MOD1[@]}" Fake)
    else
        MEC_Module=("${MEC_MOD1[@]}")
    fi

    rm -f $temp_file    #删除临时文件夹
    rm -f $temp_file_LC  
    rm -f $temp_file_check
    rm -f $temp_file_check1	
}

# syslog directory exist return 1, not exist return 0
#                  
function sysLogExist()
{
    #SysLog_config_path="$APPHOME/config/SysLog_config.xml"
    SysLog_config_path="$CONFIGHOME/SysLog_config.xml"
    local temp_path
    if [ -e $SysLog_config_path ]
    then
        temp_path=$(sed -n '/<Dir/p' $SysLog_config_path)
        APPLog=$(echo $temp_path|awk -F'[<>]' '{print $3}')
        #echo "log path is <$APPLog>"
        return 1
    else
        if [ "$LangEchoMsg" == "Chinese" ] ;then
            echo "<${SysLog_config_path}> 不存在!"
        else
            echo "<${SysLog_config_path}> does not exist!"
        fi
        return 0
    fi
}
##

function auto_path()
{
    #if [[ "$APPNAME" == "pvdmec" ]];then
    #    APPHOME=$(cd `dirname $0`;pwd)
    #    CONFIGHOME=$APPHOME/config
    #else
    #    CONFIGHOME=$(cd `dirname $0`;pwd)
    #    APPHOME=$(dirname $CONFIGHOME)
    #fi
    CONFIGHOME=$(cd `dirname $0`;pwd)
    APPHOME=$(dirname $CONFIGHOME)
    BINHOME="$APPHOME"/bin   
    MEMSHOME="$APPHOME"/
    #APPNAME=$(ls -R $BINHOME | grep -E "NMCTool|EpiTool|pvdmec|VDF" | grep -Ev "NMCTool.|EpiTool.|pvdmec.|VDF.")
    APPNAME=$(ls -R $BINHOME | grep -E "NMCTool|EpiTool|pvdmec|VDF|Mems|LED|PECVD" | grep -Ev "NMCTool.|EpiTool.|pvdmec.|VDF.|Mems.|LED.|PECVD.")
    if [[ -z $APPNAME ]];then
        APPNAME=$(ls -R $MEMSHOME | grep -E "Mems|PECVD" | grep -Ev "Mems.|PECVD.")
        if [[ -z $APPNAME ]];then
        	if [ "$LangEchoMsg" == "Chinese" ] ;then
            		echo $APPNAME "bin目录下找不到可执行文件，请确认"
        	else
            		echo "Can't find executable file in bin. please check first"
        	fi
            echo "terminal will close after 60s"
        	sleep 60
        	exit 0
        else
		    #echo $APPNAME 
		    APPSTART=$(find $MEMSHOME -name $APPNAME)
        fi      
    else
        APPSTART=$(find $BINHOME -name $APPNAME)
    fi
    cd $APPHOME
    x=1   # Start launch and AutoObtainCfg only once
    flag=true
    #set SimulatedFlag or Simulated
    while true;do
        simulated="SimulatedFlag_"
        #result=$(find ./config/ -name "${simulated}*")
        result=$(find $CONFIGHOME -name "${simulated}*")
        if [[ -n ${result[0]} ]] ;then
            break;
        fi
        simulated="Simulated_"
        #result=$(find ./config/ -name "${simulated}*")
	result=$(find $CONFIGHOME -name "${simulated}*")
        if [[ -n ${result[0]} ]] ;then
            break;
        fi
        break;
    done
   
    sysLogExist
}
##


function showLog(){
    #cd $CONFIGHOME
    logPath=`grep "<Dir>" ${CONFIGHOME}/SysLog_config.xml | awk -F '[<>]' '{print \$3}'`
    echo "logPath=${logPath}"
    echo 888888|sudo -S chmod -R 777 $logPath > /dev/null 2>&1
<<'COMMENT'
    logFilePath=`date +%Y%m%d`
    echo "logFilePath = ${logFilePath}"
    if [[ -d "${logPath}/${logFilePath}" ]]
    then
        logFile=`ls -l ${logPath}/${logFilePath}/ -rt | tail -1 | awk -F ' ' '{print $NF}'`
        echo "logFile=${logFile}"
        cat ${logPath}/${logFilePath}/${logFile}
    fi
COMMENT
    #cd -
}

##
function StartApp() {
    running_pid=$(pgrep $APPNAME)
<<'COMMENT'
    running_pid=$(pgrep $APPNAME)
    #echo $running_pid
    if [[ -n "$running_pid" ]];then
        clear

    	if [ "$LangEchoMsg" == "Chinese" ] ;then
            echo "*************************************************************"
            echo "*** 应用PID已存在，如需跳过，请按C；如需杀死当前已存在应用进程，请按K" 
            echo "*************************************************************"
            echo -e "请输入: C(跳过) , K(杀死当前进程) :\c"
        else
            echo "*************************************************************"
            echo "*** $APPNAME is already existed,if you want to skip,please enter C;if you want to kill existed pid,please enter K" 
            echo "*************************************************************"
            echo -e "Please enter: C(Continue) , K(Kill existed pid) :\c"
        fi
	
        read OPT
    	if [ "$OPT" == "C" -o "$OPT" == "c" ]; then
		    return 0
	    fi
	    if [ "$OPT" == "K" -o "$OPT" == "k" ]; then
            for pid_item in ${running_pid}
            do
                kill -9 ${pid_item} >/dev/null 2>&1  # 9 = SIGKILL
            done
	    fi 

        if [ "$LangEchoMsg" == "Chinese" ] ;then
            echo "*************************************************************"
            echo "*** 应用已存在,脚本只支持启动一个应用，如需启动多个应用，请手动启动" 
        else
            echo "*************************************************************"
            echo "*** $APPNAME is already existed, launch.sh only allows one $APPNAME. If need to start more than  one $APPNAME ,please start by command" 
        fi
        return 0
    fi
COMMENT

    while [[ ! -z $(pgrep $APPNAME) ]];do
        cmd=$(cat /proc/"$(pgrep $APPNAME)"/cmdline)
        #echo "cmd is $cmd"
        isProtect=$(echo "$cmd" | grep ProtectEtch)
        #echo "isProtect is $isProtect"
        if [[ ! -z $isProtect ]] && [[ ! -z $(pgrep $APPNAME) ]];then 
            if [ "$LangEchoMsg" == "Chinese" ] ;then
                echo "过刻保护运行中，请稍候"
            else
                echo "ProtectEtch is running,please wait"
            fi
            sleep 1
        elif [[ ! -z $(pgrep $APPNAME) ]];then
            if [ "$LangEchoMsg" == "Chinese" ] ;then
                echo "*************************************************************"
                echo "另一个 $APPNAME 正在运行中，具体命令为 $cmd,请联系软件工程师确认该命令是否正确"
                echo "脚本只支持启动一个应用，如需启动多个应用，请手动启动,或者选择 c 杀掉当前进程"
            else
                echo "*************************************************************"
                echo "There is another  $APPNAME, cmd is $cmd, please contact software engineer to confirm if the command "
                echo " Launch.sh only allows one $APPNAME. If need to start more than  one $APPNAME ,please start by command. Or you can choose c to exit"
            fi
            return 0
        fi
    done

    sysLogExist
    if [[ $? -eq 0 ]];then
        sleep 60
        exit 0
    fi
    
    # change the symbol of success and failed
    # No need to change log
    #cd $APPLog
    #sysLogNewTop2=$(ls -lrt|tail -2|awk '{print $9}')
    #for log in $sysLogNewTop2
    #do
        #sed -i 's/pvdmec started successfully!/pvdmec started-sed successfully!/g' $log
        #sed -i 's/pvdmec starts unsuccessfully!/pvdmec starts-sed unsuccessfully!/g' $log
    #done
    
    if [ "$LangEchoMsg" == "Chinese" ] ;then
        echo "$APPNAME 启动中..."
    else
        echo "$APPNAME is starting..."
    fi
    sleep 5 # liuxq : don't let 'sleep 10' just in front of 'exit 0', otherwise this will cause 'pvdmec is terminated by interrupt during startup sequence'.
    
    ## Option 1. no output file
    #nohup $APPSTART $CONFIGHOME > /dev/null 2>&1 &  //ceshi
    #$APPSTART $CONFIGHOME
    ##
    
    ## Option 2. has output file, work with system monitor, system monitor will clear it when size over 500M
 
    #added for yike
    cd $CONFIGHOME
    echo 888888|sudo -S chmod -R 777 $CONFIGHOME > /dev/null 2>&1
    if [ -d $CONFIGHOME/ProtectEtch ]; then
        mv $CONFIGHOME/ProtectEtch $APPHOME
    fi
    ##source /etc/profile  #保证环境变量起效
    CheckPATH_1st  #check PATH and source
    CheckPATH_2nd  #source doesn't work ,check /etc/profile manually 
    cd $APPHOME # if delete this line, nohup_mec_output.txt will stop update after MEC started successfully
    if [ ! -d "./nohup" ]; then
        mkdir -p ./nohup
    fi 
    if [ -e *nohup*.txt ]; then   
        mv *nohup*.txt ./nohup
    fi
    #keep the latest 30 nohup*.txt
    cd $APPHOME/nohup
    while [ $(ls -l | grep nohup | wc -l) -gt 30 ];do
        ls -l | grep nohup | wc -l > /dev/null 2>&1
        rm -rf $(ls -rt | head -n1)
    done
    #start APP
    local targetPath=$APPHOME/nohup_mec_output_$(date +"%Y%m%d_%H%M%S").txt
    #archBit=$(getconf LONG_BIT)
    kernel=$(uname -r)
    #add taskset for SUSE
    tasksetResult=0
    if [[ $kernel == "5.3.18-39-rt" ]];then
        echo 888888|sudo loginctl enable-linger root
    fi
    if [[ $kernel == "5.3.18-39-rt" ]] && [[ "$isTaskset" == "Y" || "$isTaskset" == "y" ]];then
        #sudo loginctl enable-linger root
        cores=$(lscpu --extended -b | grep -v ONLINE|wc -l)
        echo "isTaskset is $isTaskset"
        if [[ $cores > 3  ]]; then
    	    tasksetResult=1
        else
            echo "num of cores is $cores, taskset -c 1-3 require more than 4 cores"
        fi
    fi
    cd $APPHOME #make sure coredump is saved with bin 
    if [[ $tasksetResult -eq 0 ]];then
       # nohup $APPSTART $CONFIGHOME > $targetPath 2>&1 &
       setsid $APPSTART $CONFIGHOME > $targetPath 2>&1 &
    else
        echo "$APPNAME already taskset for cpu 1-3"
        #nohup taskset -c 1-3 $APPSTART $CONFIGHOME > $targetPath 2>&1 &
        setsid taskset -c 1-3 $APPSTART $CONFIGHOME > $targetPath 2>&1 &
        #setsid taskset -c 0 $APPSTART $CONFIGHOME > $targetPath 2>&1 &
    fi
    ##

    cd $APPLog
    local findResult=0 # songxl success or failed
    local try_count=0
    sleep 5
    #starting time last for 10 min 
    while [[ $try_count -lt 600 ]]; do
        success_pid=$(pgrep $APPNAME)
        #echo $success_pid
        if [[ -n "$success_pid" ]];then #starts successfully!
	    matchLine=$(grep 'started successfully!' $targetPath)
	    #echo "$matchline"
            if [[ -n  "$matchLine" ]];then
		if [ "$LangEchoMsg" == "Chinese" ] ;then
                    echo "$APPNAME 启动成功"
                    echo "$APPNAME 已转为后台运行"
                    echo "$APPNAME 的启动命令绝对路径是: "
                    echo "$APPSTART $CONFIGHOME"
		else
		    echo "$APPNAME start successfully"
                    echo "$APPNAME is already running in the background"
                    echo "The path of $APPNAME is : "
                    echo "$APPSTART $CONFIGHOME"
		fi
		findResult=1
	    fi
            matchLine=$(grep 'started unsuccessfully!' $targetPath)
            if [[ -n  "$matchLine" ]];then
                if [ "$LangEchoMsg" == "Chinese" ] ;then
                    echo "$APPNAME 启动失败, 请打开 $APPLog/$log或者同级目录下nohup开头的日志查看更多信息,如需查看端口使用情况请按p"
                else
                    echo "$APPNAME start unsuccessfully, please check $APPLog/$log or nohup*.txt for details, check port number please Enter p"
                fi
                findResult=2
            fi     
        else #starts unsuccessfully!
<<'COMMENT'
            matchLine=$(grep 'started unsuccessfully!' $targetPath)
            if [[ -n  "$matchLine" ]];then
                if [ "$LangEchoMsg" == "Chinese" ] ;then
                    echo "$APPNAME 启动失败, 请打开 $APPLog/$log或者同级目录下nohup开头的日志查看更多信息,如需查看端口使用情况请按p"
                else
                    echo "$APPNAME start unsuccessfully, please check $APPLog/$log or nohup*.txt for details, check port number please Enter p"
                fi
                findResult=2
	        #exit 0
            #break
            fi
COMMENT
            if [ "$LangEchoMsg" == "Chinese" ] ;then
                echo "$APPNAME 启动失败, 请打开 $APPLog/$log或者同级目录下nohup开头的日志查看更多信息,如需查看端口使用情况请按p"
            else
                echo "$APPNAME start unsuccessfully, please check $APPLog/$log or nohup*.txt for details, check port number please Enter p"
            fi
            findResult=2
        fi
        
        if [[ $findResult -eq 0 ]];then
            try_count=$(($try_count + 1)) # 0 need wait result
            sleep 1
        else
            sleep 5
            return 0
        fi

	#over 3min,post alarm
	if [[ try_count -eq 300 ]];then # 300 seconds past,maybe update database
            if [ "$LangEchoMsg" == "Chinese" ] ;then
                echo "启动 $APPNAME 耗时超过300秒但是还需要更多时间，请联系软件工程师确认是否正常" 
                #flag=false #this flag can make launch.sh end
            else
                echo "start $APPNAME had cost 300 seconds but need more time, please contact software engeineer"
                #flag=false
            fi
        fi

    done
   
    return 0
}

function StartAppSlowScan()
{
    running_pid=$(pgrep 'pvdmec$')
    if [[ -z "$running_pid" ]];then
        #cd $APPHOME/config/IOBridge
	cd $CONFIGHOME/IOBridge
        sed -i 's/<!--loadFirmwareAnyway type="method"\/-->/<loadFirmwareAnyway type="method"\/>/g' Driver_*

        cd $APPHOME

        StartApp
    else
        if [ "$LangEchoMsg" == "Chinese" ] ;then
            echo "MEC 已启动, 忽略 '慢扫启动' 操作" 
        else
            echo "MEC already started, ignore StartAppSlowScan"
        fi
    fi
}

StartAppInTeminal()
{
    running_pid=$(pgrep 'pvdmec$')
    if [[ -n "$running_pid" ]];then
        if [ "$LangEchoMsg" == "Chinese" ] ;then
            echo "MEC 已启动, 忽略 '终端中启动' 操作"
        else
            echo "MEC already started, ignore StartAppInTeminal"
        fi
        exit 0
    fi
    
    sysLogExist
    if [[ $? -eq 0 ]];then
        exit 0
    fi
    
    if [ -d "$APPHOME"/bin/release ]; then
        AppRunName=$APPHOME/bin/release/pvdmec
    elif [ -d "$APPHOME"/bin/debug ]; then
        AppRunName=$APPHOME/bin/debug/pvdmec
    else
        if [ "$LangEchoMsg" == "Chinese" ] ;then
            echo "pvdmec 文件不存在，请确认"
        else
            echo "No executable exists. please 'make' first"
        fi
        exit 0 
    fi
    
    $AppRunName $CONFIGHOME

    echo "*************************************************************"         
}

ExitApp() {
    running_pid=$(pgrep $APPNAME)
    #echo $running_pid
    if [[ -z "$running_pid" ]];then #There is no pid
        if [ "$LangEchoMsg" == "Chinese" ] ;then
            echo "$APPNAME 已退出, 请选择启动(b)"
        else
            echo "$APPNAME already exited, please select StartApp(b)"
        fi
        return 0 # songxl avoid terminal close
    fi    

    clear
    if [ "$LangEchoMsg" == "Chinese" ] ;then
        echo "*************************************************************"
        echo "*** 确定要退出 <$APPNAME> ?" 
        echo "*************************************************************"
        echo -e "请输入: Y(是) , N(否) :\c"
    else
        echo "*************************************************************"
        echo "*** Do you want to exit MEC ?" 
        echo "*************************************************************"
        echo -e "Please enter: Y(Yes) , N(No) :\c"
    fi

    read OPT
    if [ "$OPT" == "Y" -o "$OPT" == "y" ]; then
        executeable_pid=$(pgrep $APPNAME)
        #kill -15 for all pid
        for pid_item in ${executeable_pid}
        do
            #echo "kill 15"
            kill -15 ${pid_item}; # 15 = SIGTERM : Termination (ANSI)
        done
        #wait APPExitTime for kill -15 
        for ((i=1; i< $(($APPExitTime + 1)); i++)); do
            executeable_pid=$(pgrep $APPNAME)
            #echo "kill 15 for  $i 秒"
            if [ $? -eq 0 ]; then 
                if [ "$LangEchoMsg" == "Chinese" ] ;then
                    echo "$APPNAME 退出已耗时 $i 秒,请稍候."
                else
                    echo "$APPNAME has been exiting for $i seconds,please wait a moment"
                fi
                sleep 1 #jidequxiaozhushi
            else
                if [ "$LangEchoMsg" == "Chinese" ] ;then
                    echo "$APPNAME 已退出!"
                else
                    echo "$APPNAME already killed."
                fi    
                return 4 # all pids shutdown normally, no need to kill
            fi      
        done

        # kill -15 failed, kill -9
        executeable_pid=$(pgrep $APPNAME)
        for pid_item in ${executeable_pid}
        do
            sleep 1
	    #echo "kill -9"
            kill -9 ${pid_item} > /dev/null 2>&1; # 9 = SIGKILL
        done
	#wait kill -9
        i=$APPExitTime       
        while [[ ! -z $(pgrep $APPNAME) ]];do
            i=$(($i + 1))
            #echo "kill -9 for  $i 秒"
            if [ "$LangEchoMsg" == "Chinese" ] ;then
                echo "$APPNAME 退出已耗时 $i 秒,请稍候."
            else
                echo "$APPNAME has been exiting for $i seconds,please wait a moment"
            fi
            #more than 300s,exit
            if [[ $i -eq 300 ]];then
               if [ "$LangEchoMsg" == "Chinese" ] ;then
                    echo "$APPNAME 进程无法被kill -9杀死，请联系软件工程师确认是否正常"
               else
                    echo "$APPNAME can not be killed by -9,please contact software engeineer"
               fi
               echo "terminal will close after 60s"
               sleep 60
               exit 0
            fi
            sleep 1
        done
        #kill -9 success check
        if [ -z $(pgrep $APPNAME) ];then
            if [ "$LangEchoMsg" == "Chinese" ] ;then
                echo "$APPNAME 已退出!"
            else
                echo "$APPNAME already killed."
            fi    
            return 4
        else
           if [ "$LangEchoMsg" == "Chinese" ] ;then
               echo "$APPNAME 进程无法被kill -9杀死，请联系软件工程师确认是否正常"
           else
               echo "$APPNAME can not be killed by -9,please contact software engeineer"
           fi 
           echo "terminal will close after 60s"
           sleep 60
           exit 0
        fi
    #option for no
    else
        return 0
    fi

    return 0 # songxl avoid terminal close   
} 

RestartApp() {
    ExitApp
    if [[ $? -eq 4 ]]; then # Confirmed Exit
        for ((i=30; i>0; i--)); do
            if [ "$LangEchoMsg" == "Chinese" ] ;then
                echo "$APPNAME 将在 $i 秒之后启动."
            else
                echo "$APPNAME will start after $i seconds."
            fi
            
            sleep 1
        done
        StartApp
    fi
}

Debugger() {
    cd /opt/Debugger
    source /etc/profile
    #setsid /opt/Debugger/Debugger & > /dev/null 2>&1
    setsid /opt/Debugger/Debugger > /dev/null 2>&1 &
}

CheckPATH_1st()
{
    ld_path1=$(echo $LD_LIBRARY_PATH | grep IAP)
    if [[ -z "$ld_path1" ]];then #There is no IAP path
        source /etc/profile
    fi    	
}

CheckPATH_2nd()
{
    ld_path2=$(echo $LD_LIBRARY_PATH | grep IAP)
    if [[ -z "$ld_path2" ]];then #There is no IAP path
        if [ "$LangEchoMsg" == "Chinese" ] ;then
                echo "IAP不在系统环境路径中，请检查/etc/profile"
        else
                echo "There is no IAP in the PATH,please check/etc/profile"
        fi
    fi 	
}

ShowPort()
{
    clear
    if [ "$LangEchoMsg" == "Chinese" ] ;then
        read -p "请输需要查看的端口号:" OPT
    else
        read -p "Please enter port number:" OPT
    fi
    #netstat -antlp | grep $OPT
    #port=$(netstat -antlp | grep $OPT)
    lsof -i:$OPT
    port=$(lsof -i:$OPT)
    if [[ -z "$port" ]];then #There is no IAP path
        if [ "$LangEchoMsg" == "Chinese" ] ;then
	    echo "*************************************************************"
            echo "端口号未被占用"
        else
	    echo "*************************************************************"
            echo "The port number is not using"
        fi
    fi    
}


ShowCurrentCfg(){    # Called by ConfigureApp to show current configuration 
    if [ "$1" == "REBUILT" ]; then
        clear

        while [ $x -le 1 ];do  # Start launch and AutoObtainCfg only once
            AutoObtainCfg	
            let x++    #let定义变量并赋值
        done

        echo "*************************************************************"
        if [ "$LangEchoMsg" == "Chinese" ] ;then
            echo "*                DeviceNet 扫描设置                 "
        else
            echo "*                DeviceNet scan configration                 "
        fi
        echo "*************************************************************"
        cd $CONFIGHOME/IOBridge
        
        for ((i=0; i<${#MEC_DeviceNet[*]};i++)) ;do
            grep -sq "loadFirmwareAnyway type=\"method\"" Driver_${MEC_DeviceNet[$i]}; # Weather a Driver_ file(contains a DeviceNet firmware setting) 
            ret=$?
            
            if [ $i -lt 10 ]; then
                Asterisk="****"
            else
                Asterisk="***"
            fi
            
            if [ "$ret" == "1" ]; then
                if [ "$LangEchoMsg" == "Chinese" ] ;then
                    echo "$Asterisk$i: ${MEC_DeviceNet[$i]} (错误: 找不到'loadFirmwareAnyway'配置项)"; # can not find DeviceNet firmware setting
                else
                    echo "$Asterisk$i: ${MEC_DeviceNet[$i]} (Error: Can not find firmware)"; # can not find DeviceNet firmware setting
                fi
            elif [ "$ret" == "2" ]; then
                if [ "$LangEchoMsg" == "Chinese" ] ;then
                    echo "$Asterisk$i: ${MEC_DeviceNet[$i]} (错误: 未知 DeviceNet)" # can not find the file
                else
                    echo "$Asterisk$i: ${MEC_DeviceNet[$i]} (Error: unknown DeviceNet)" # can not find the file
                fi
            else
                grep -q "<loadFirmwareAnyway type=\"method\"\/>" Driver_${MEC_DeviceNet[$i]}
                ret=$?
                if [ "$ret" == "0" ]; then
                    if [ "$LangEchoMsg" == "Chinese" ] ;then
                        echo "$Asterisk$i: ${MEC_DeviceNet[$i]} (重建)"
                    else
                        echo "$Asterisk$i: ${MEC_DeviceNet[$i]} (REBUILT)"
                    fi
                else
                    echo "$Asterisk$i: ${MEC_DeviceNet[$i]} "
                fi
            fi
        done
    elif [ "$1" == "SIMULATE" ]; then
        clear

        while [ $x -le 1 ];do   # Start launch and AutoObtainCfg only once 
            AutoObtainCfg	
            let x++   
        done	

        echo "*************************************************************"
            if [ "$LangEchoMsg" == "Chinese" ] ;then
                echo "*               模拟设置              "
            else
                echo "*               Module Simulation configuration              "
            fi
        echo "*************************************************************"
        cd $CONFIGHOME

        for ((i=0; i<${#MEC_Module[*]};i++)); do
            grep -sqE "true</setSimulated>|false</setSimulated>" ${simulated}${MEC_Module[$i]}; # Weather a SimulatedFlag_ file(contains a 'setSimulated' method) 
            ret=$?

            if [ $i -lt 10 ]; then
                Asterisk="****"
            else
                Asterisk="***"
            fi
            
            if [ "$ret" == "1" ]; then
                if [ "$LangEchoMsg" == "Chinese" ] ;then
                    echo "$Asterisk$i: ${MEC_Module[$i]} (错误: 找不到 SimulatedFlag)"; # can not find 'setSimulated' method
                else
                    echo "$Asterisk$i: ${MEC_Module[$i]} (Error: Can not find SimulatedFlag)"; # can not find 'setSimulated' method
                fi
            elif [ "$ret" == "2" ]; then
                if [ "$LangEchoMsg" == "Chinese" ] ;then
                    echo "$Asterisk$i: ${MEC_Module[$i]} (错误: 未知腔室)"; # can not find the file
                else
                    echo "$Asterisk$i: ${MEC_Module[$i]} (Error: unknown module)"; # can not find the file
                fi
            else
                grep -q "true</setSimulated>" ${simulated}${MEC_Module[$i]}
                ret=$?
                if [ "$ret" == "0" ]; then
                    if [ "$LangEchoMsg" == "Chinese" ] ;then
                        echo "$Asterisk$i: ${MEC_Module[$i]} (模拟)"
                    else
                        echo "$Asterisk$i: ${MEC_Module[$i]} (SIMULATE)"
                    fi
                else
                    echo "$Asterisk$i: ${MEC_Module[$i]} "
                fi
            fi
        done
    fi
    
    echo "*************************************************************"
    echo "***A: All , N: None , Q: back" 
    echo "*************************************************************"
        
    if [ "$LangEchoMsg" == "Chinese" ] ;then
        echo -e "请输入操作对应的字母并按回车 :\c"
    else
        echo -e "Please select and press the Enter key :\c"
    fi
}

ConfigureApp() {    # Edit launch settings
    clear
    if [ "$LangEchoMsg" == "Chinese" ] ;then
        echo "*                 MEC 启动设定                   "
        echo "*************************************************************"
        echo "**1) DeviceNet 扫描设置"
        echo "**2) 模拟设置"
        echo "*************************************************************"
        echo -e "请输入操作对应的字母并按回车:\c"
    else
        echo "*                 Program startup settings                   "
        echo "*************************************************************"
        echo "**1) DeviceNet scan configration"
        echo "**2) Modules Simulation configuration"
        echo "*************************************************************"
        echo -e "Please enter option and press <Enter>:\c" 
    fi 

read OPT
case $OPT in

    1)
        while [ "$OPT" != "q" -a "$OPT" != "Q" ]; do
            ShowCurrentCfg REBUILT
            read OPT
            if [ "$OPT" == "a" -o "$OPT" == "A" ]; then    # Rebuilt all DeviceNets in MEC_DeviceNet_Manager
                for ((i=0; i<${#MEC_DeviceNet[*]};i++)) ;do
                    sed -i 's/<!--loadFirmwareAnyway type="method"\/-->/<loadFirmwareAnyway type="method"\/>/g' Driver_${MEC_DeviceNet[$i]}
                done
            elif  [ "$OPT" == "n" -o "$OPT" == "N" ]; then    # Skip all DeviceNets in MEC_DeviceNet_Manager
                for ((i=0; i<${#MEC_DeviceNet[*]};i++)) ;do
                    sed -i 's/<loadFirmwareAnyway type="method"\/>/<!--loadFirmwareAnyway type="method"\/-->/g' Driver_${MEC_DeviceNet[$i]}
                done
            else
                for ((i=0; i<${#MEC_DeviceNet[*]};i++)) ;do    # Rebuilt the chosen DeviceNets
                    echo $OPT | grep  -w "$i"
                    if [[ $? -eq 0 ]]; then
                        grep -sq '!--loadFirmwareAnyway' Driver_${MEC_DeviceNet[$i]}
                        if [[ $? -eq 0 ]];then
                            sed -i 's/<!--loadFirmwareAnyway type="method"\/-->/<loadFirmwareAnyway type="method"\/>/g' Driver_${MEC_DeviceNet[$i]}
                        else
                            sed -i 's/<loadFirmwareAnyway type="method"\/>/<!--loadFirmwareAnyway type="method"\/-->/g' Driver_${MEC_DeviceNet[$i]}
                        fi
                        break
                    fi
                done
            fi
        done
        ;;

    2) 
        while [ "$OPT" != "q" -a "$OPT" != "Q" ]; do
            ShowCurrentCfg SIMULATE
            read OPT
            if [ "$OPT" == "n" -o "$OPT" == "N" ]; then    # Materialize all modules in MEC_Module array
                for ((i=0; i<${#MEC_Module[*]};i++)); do
                    sed -i 's/true/false/g' ${simulated}${MEC_Module[$i]}
                done
            elif  [ "$OPT" == "a" -o "$OPT" == "A" ];then    # Simulate all modules in MEC_Module array
                for ((i=0; i<${#MEC_Module[*]};i++)); do
                    sed -i 's/false/true/g' ${simulated}${MEC_Module[$i]}
                done
            else
                for ((i=0; i<${#MEC_Module[*]};i++)); do    # Simulate the chosen modules
                    echo $OPT | grep -w "$i"
                    if [[ $? -eq 0 ]]; then
                        grep -sq false ${simulated}${MEC_Module[$i]}
                        if [[ $? -eq 0 ]];then
                            sed -i 's/false/true/g' ${simulated}${MEC_Module[$i]}
                        else
                            sed -i 's/true/false/g' ${simulated}${MEC_Module[$i]}
                        fi
                        break
                    fi
                done
            fi
        done
        ;;
esac
}

auto_path
#echo "please Enter AppName, n for NMCTool, p for pvdmec, v for NAURA_VDF_TOOL, e for EpiTool"
#read OPT
#case $OPT in
#            N|n) APPNAME=NMCTool;;
#	    P|p) APPNAME=pvdmec;;
#            V|v) APPNAME=NAURA_VDF_TOOL;;
#            E|e) APPNAME=EpiTool;;
#	    *) echo "Wrong AppName, please choose AppName provided above"
#	       exit 0;;
#esac
echo "APPNAME is $APPNAME" 
while $flag ; do
    running_pid=$(pgrep $APPNAME)
    #clear
    if [ "$LangEchoMsg" == "Chinese" ] ;then
        echo "------------------------------------------------------------"
        echo "                         <NAURA_LAUNCH>                      "
        echo "                         版本 2025.05.20                     "
        echo "*************************************************************"
        if [[ -z "$running_pid" ]];then
            echo "$APPNAME 未启动..."
            echo "如有需要,请选择启动(b)."
            echo "-------------------------------------------------------------"
            #echo "* a) 启动 MEC (DeviceNet强制重建，PVD专用)"
            echo "* b) 启动 $APPNAME"
        else
            echo "$APPNAME 已启动..."
            echo "如有需要,请选择退出(c) 或 重启(r)."
            echo "-------------------------------------------------------------"
            
        fi
            echo "* c) 退出 $APPNAME"
            echo "* d) 启动 Debugger"
            echo "* r) 重启 $APPNAME"
            echo "* l) 查看 日志路径"
        #if [[ -z "$running_pid" ]];then
        #    echo "* s) 启动 MEC (终端模式)"
        #fi
            #echo "* x) 配置 MEC（PVD专用）"
	        echo "* p) 查看 端口号"
	        #echo "* l) 查看 日志"
            echo "* q) 退出 启动器"
       
        echo "*************************************************************"
        read -p "请输入操作对应的字母并按回车:" OPT
    else
        echo "-------------------------------------------------------------"
        echo "                         <NAURA_LAUNCH>                      "
        echo "                       Version 2025.05.20                    "
        echo "*************************************************************"
        if [[ -z "$running_pid" ]];then
            echo "$APPNAME isn't running..."
            echo "If needed, please select StartApp(b) option."
            echo "-------------------------------------------------------------"
           # echo "* a) Start MEC (Rebuild DeviceNet Forced，only for PVD)"
            echo "* b) Start $APPNAME"
        else
            echo "$APPNAME is already running..."
            echo "If needed, please to select Exit(c) or Restart(r) option."
            echo "-------------------------------------------------------------"
        fi
            echo "* c) Exit  $APPNAME"
            echo "* d) Debugger"
            echo "* r) Restart $APPNAME"
            echo "* l) show Syslog path"
        #if [[ -z "$running_pid" ]];then
        #    echo "* s) Start MEC (Teminal Mode)"
        #fi
            #echo "* x) Configure MEC(only for PVD)"
	    echo "* p) show Port Usage"
            echo "* q) Exit launch"
   
        echo "*************************************************************"
        read -p "Please enter option and press <Enter>:" OPT
    fi 

    case $OPT in
            #a|A) StartAppSlowScan;;
            b|B) StartApp;;
            c|C) ExitApp;;
            d|D) Debugger;;
            r|R) RestartApp;;
            p|P) ShowPort;;
	    l|L) showLog;;
            # s|S) StartAppInTeminal;;
            # x|X) ConfigureApp;;
            q|Q) exit 0;;
    esac
done
