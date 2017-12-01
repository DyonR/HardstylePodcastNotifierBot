#Telegram API Data
$TelegramBotToken = "INSERT API TOKEN HERE"
$ChatId = "INSERT CHAT ID HERE"

#Define the Hardstyle Podcast infomation down here
#Blackburn & Aeros present BMBSQD
$BMBSQDIdFile = "$env:TEMP\HardstyleMonitor\BMBSQD.txt"
$BMBSQDId ="{0:D2}" -f [int](Get-Content $BMBSQDIdFile) #Example 01
$BMBSQDTitle = "Blackburn %26 Aeros present BMBSQD - Episode"
$BMBSQDUrl = "http://traffic.libsyn.com/bombsquad/Blackburn__Aeros_present_BMBSQD_-_Episode_$BMBSQDId`_BSQ$BMBSQDId`.mp3"

#Brennan Heart presents WE R Hardstyle
$BrennanIdFile = "$env:TEMP\HardstyleMonitor\Brennan.txt"
$BrennanId = "{0:D3}" -f [int](Get-Content $BrennanIdFile) #Example 53
$BrennanTitle = "Brennan Heart presents WE R Hardstyle %7C Episode"
$BrennanUrl = "http://media2-brennanheart.podtree.com/media/podcast/Brennan_Heart_-_WE_R_Hardstyle_$BrennanId`.m4a"

#Coone - Global Dedication
$CooneIdFile = "$env:TEMP\HardstyleMonitor\Coone.txt"
$CooneTitle = "Coone - Global Dedication - Episode"

#Digital Punk - Unleashed
$DigitalPunkIdFile = "$env:TEMP\HardstyleMonitor\DigitalPunk.txt"
$DigitalPunkId = "{0:D3}" -f [int](Get-Content $DigitalPunkIdFile) #Example 001
$DigitalPunkTitle = "Digital Punk - Unleashed"
$DigitalPunkUrl = "http://traffic.libsyn.com/a2recordsunleashed/iTunes_Unleashed_$DigitalPunkId.m4a"

#Evil Activities presents: Extreme Audio
$ExtremeIdFile = "$env:TEMP\HardstyleMonitor\Extreme.txt"
$ExtremeId = "{0:D2}" -f [int](Get-Content $ExtremeIdFile) #Example 64
$ExtremeTitle = "Evil Activities presents: Extreme Audio - Episode"
$ExtremeUrl = "http://traffic.libsyn.com/extremeaudio/ExtremeAudio_EP$ExtremeId`.m4a"

#HARD with STYLE
$HWSIdFile = "$env:TEMP\HardstyleMonitor\HWS.txt"
$HWSId = "{0:D2}" -f [int](Get-Content $HWSIdFile) #Example 70
$HWSTitle = "HARD with STYLE - Episode %23"
$HWSUrl = "http://podcast.hardwithstyle.nl/HWS$HWSId`_Presented_by_Headhunterz.mp3"

#Isaac's Hardstyle Sessions
$IsaacIdFile = "$env:TEMP\HardstyleMonitor\Isaac.txt"
$IsaacId = [int](Get-Content $IsaacIdFile) #Example 70
$IsaacTitle = "Isaac's Hardstyle Sessions %23"
$IsaacUrl = "http://traffic.libsyn.com/djisaac/ISAACS_HARDSTYLE_SESSIONS_$IsaacId`__" + (Get-Date -Format MMMM).ToUpper() + "_" + (Get-Date -Format yyyy) + ".m4a"

#Spirit of Hardstyle
$SOHIdFile = "$env:TEMP\HardstyleMonitor\SOH.txt"
$SOHId = "{0:D3}" -f ([int](Get-Content $SOHIdFile)) #Example 002
$SOHTitle = "Spirit Of Hardstyle Podcast |"
$SOHUrl = "https://traffic.libsyn.com/spiritofhardstyle/$SoHId`__Spirit_Of_Hardstyle.m4a"


function CheckURL{
    param(
        [Parameter(Mandatory=$true)][string]$PodcastURL,
        [Parameter(Mandatory=$true)][string]$PodcastEpisodeId,
        [Parameter(Mandatory=$true)][string]$PodcastTitle,
        [Parameter(Mandatory=$true)][string]$PodcastShortName,
        [Parameter(Mandatory=$true)][string]$PodcastTempPath
    )

    try{
        $PodcastUrlResponse = Invoke-WebRequest -Uri $PodcastURL -MaximumRedirection 0 -ErrorAction Ignore -DisableKeepAlive -UseBasicParsing -Method Head
        try{
			$TelegramResponse = Invoke-WebRequest -Uri "https://api.telegram.org/bot$TelegramBotToken/sendMessage?chat_id=$ChatId&parse_mode=markdown&text=[$PodcastTitle $PodcastEpisodeId]($PodcastURL)" -Method POST
			if($TelegramResponse.StatusCode -eq "200"){
				Write-Host "New $PodcastShortName Episode! Message has successfully been sent."
				[int]$NewPodcastId = $PodcastEpisodeId
                $NewPodcastId++
				Write-Output $NewPodcastId | Out-File $PodcastTempPath
                return $true
			}
		}
		catch{
			if($_.Exception.InnerException.Response.StatusCode.value__ -ne "200"){
				Write-Host "An error occured when trying to send a message to Telegram."
			}
		}
    }
    catch{
        #if($_.Exception.Response.StatusCode.value__ -eq "404"){
        #    Write-Host "$PodcastShortName $PodcastEpisodeId is not yet online." 
        #}
    }
}

function CheckCoone{
    $LastGlobalTitle = Get-Content $CooneIdFile
    $GlobalDedicationFeed = [xml](Invoke-WebRequest "http://podcast.globaldedication.com/feed/")
    $NewGlobalTitle = $GlobalDedicationFeed.rss.channel.item[0].title
    if($NewGlobalTitle -ne $LastGlobalTitle){
        $GlobalUrl = $GlobalDedicationFeed.rss.channel.item[0].link
        if($NewGlobalTitle.Contains("#")){
           $NewGlobalTitleTelegram = $NewGlobalTitle -Replace '\#', '%23'
        }
        if($NewGlobalTitle.Contains("#")){
           $NewGlobalTitleTelegram = $NewGlobalTitle -Replace '\#', '%23'
        }
         try{
            $TelegramResponse = Invoke-WebRequest -Uri "https://api.telegram.org/bot$TelegramBotToken/sendMessage?chat_id=$ChatId&parse_mode=markdown&text=[$NewGlobalTitleTelegram]($GlobalUrl)" -Method POST
            if($TelegramResponse.StatusCode -eq "200"){
				Write-Host "New Global Dedication Episode! Message has successfully been sent."
				Write-Output $NewGlobalTitle | Out-File $CooneIdFile
		    }
        }
        catch{
            	if($_.Exception.InnerException.Response.StatusCode.value__ -ne "200"){
				Write-Host "An error occured when trying to send a message to Telegram."
			}
        }
    }
	#else{
	#	Write-Host "A new Global Dedication is not yet online." 
	#}
}

while($true){
    
    #Blackburn & Aeros present BMBSQD
    if(CheckURL -PodcastURL $BMBSQDUrl -PodcastEpisodeId $BMBSQDId -PodcastTitle $BMBSQDTitle -PodcastShortName "BMBSQD" -PodcastTempPath $BMBSQDIdFile){
        $BMBSQDId ="{0:D2}" -f [int](Get-Content $BMBSQDIdFile) #Example 01
        $BMBSQDUrl = "http://traffic.libsyn.com/bombsquad/Blackburn__Aeros_present_BMBSQD_-_Episode_$BMBSQDId`_BSQ" + [int]$BMBSQDId + ".mp3"
    }
    #Brennan Heart presents WE R Hardstyle
    if(CheckURL -PodcastURL $BrennanUrl -PodcastEpisodeId $BrennanId -PodcastTitle $BrennanTitle -PodcastShortName "Brennan" -PodcastTempPath $BrennanIdFile){
        $BrennanId = "{0:D3}" -f [int](Get-Content $BrennanIdFile)
        $BrennanUrl = "http://media2-brennanheart.podtree.com/media/podcast/Brennan_Heart_-_WE_R_Hardstyle_$BrennanId`.m4a"
    }

    #Coone - Global Dedication
    CheckCoone

    #Digital Punk - Unleashed
    if(CheckURL -PodcastURL $DigitalPunkUrl -PodcastEpisodeId $DigitalPunkId -PodcastTitle $DigitalPunkTitle -PodcastShortName "DigitalPunk" -PodcastTempPath $DigitalPunkIdFile){
        $DigitalPunkId = "{0:D3}" -f [int](Get-Content $DigitalPunkIdFile)
        $DigitalPunkUrl = "http://traffic.libsyn.com/a2recordsunleashed/iTunes_Unleashed_$DigitalPunkId.m4a"
    }
    #Evil Activities presents: Extreme Audio
    if(CheckURL -PodcastURL $ExtremeUrl -PodcastEpisodeId $ExtremeId -PodcastTitle $ExtremeTitle -PodcastShortName "Extreme" -PodcastTempPath $ExtremeIdFile){
        $ExtremeId = "{0:D2}" -f [int](Get-Content $ExtremeIdFile)
        $ExtremeUrl = "http://traffic.libsyn.com/extremeaudio/ExtremeAudio_EP$ExtremeId`.m4a"
    }
    #HARD with STYLE
    if(CheckURL -PodcastURL $HWSUrl -PodcastEpisodeId $HWSId -PodcastTitle $HWSTitle -PodcastShortName "HWS" -PodcastTempPath $HWSIdFile){
        $HWSId = "{0:D2}" -f [int](Get-Content $HWSIdFile)
        $HWSUrl = "http://podcast.hardwithstyle.nl/HWS$HWSId`_Presented_by_Headhunterz.mp3"
    }
    #Isaac's Hardstyle Sessions
    if(CheckURL -PodcastURL $IsaacUrl -PodcastEpisodeId $IsaacId -PodcastTitle $IsaacTitle -PodcastShortName "Isaac" -PodcastTempPath $IsaacIdFile){
        $IsaacId = [int](Get-Content $IsaacIdFile)
        $IsaacUrl = "http://traffic.libsyn.com/djisaac/ISAACS_HARDSTYLE_SESSIONS_$IsaacId`__" + (Get-Date -Format MMMM).ToUpper() + "_" + (Get-Date -Format yyyy) + ".m4a"
    }

    #Spirit of Hardstyle
    if(CheckURL -PodcastURL $SOHUrl -PodcastEpisodeId $SoHId -PodcastTitle $SOHTitle -PodcastShortName "SOH" -PodcastTempPath $SOHIdFile){
        $SOHId = "{0:D3}" -f ([int](Get-Content $SOHIdFile)) #Example 002
        $SOHUrl = "https://traffic.libsyn.com/spiritofhardstyle/$SoHId`__Spirit_Of_Hardstyle.m4a"
    }
    Start-Sleep 10
}
