#Get the path 
$ScriptPath = Get-Location
$Podcasts = ls $ScriptPath\PodcastsConfig\*.xml | ForEach-Object {$_.BaseName}

#Load the config
[xml]$Config = Get-Content ".\config.xml"

#Telegram API Data
$TelegramBotToken = $Config.config.TelegramSettings.BotToken
$TelegramChatId = $Config.config.TelegramSettings.ChatID

#BotSettings
$ForceRSS = $Config.config.BotSettings.ForceRSS


function CheckURL{
    param(
        [Parameter(Mandatory=$true)][string]$PodcastURL,
        [Parameter(Mandatory=$true)][int]$PodcastEpisodeId,
        [Parameter(Mandatory=$true)][string]$PodcastTitle
    )

    $PodcastEpisodeId++
    try{
        $PodcastUrlResponse = Invoke-WebRequest -Uri $PodcastURL -MaximumRedirection 0 -ErrorAction Ignore -DisableKeepAlive -UseBasicParsing -Method Head
        try{
			$TelegramResponse = Invoke-WebRequest -Uri "https://api.telegram.org/bot$TelegramBotToken/sendMessage?chat_id=$TelegramChatId&parse_mode=markdown&text=[$PodcastTitle$PodcastEpisodeId]($PodcastURL)" -Method POST
			if($TelegramResponse.StatusCode -eq "200"){
				Write-Host "New $ShortName Episode! Message has successfully been sent."
				[int]$NewPodcastId = $PodcastEpisodeId
                $PodcastInfo.$ShortName.ChildNodes.Item(1).'#text' = ($NewPodcastId++).ToString()
                $PodcastInfo.Save("$ScriptPath\PodcastsConfig\" + $ShortName + ".xml")
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
        #    Write-Host "$ShortName $PodcastEpisodeId is not yet online." 
        #}
    }
}

function CheckRSS{
    param(
        [Parameter(Mandatory=$true)][string]$LastReleaseTitle,
        [Parameter(Mandatory=$true)][string]$rssUrl
    )
    #if($rssUrl -like "*libsyn*"){
        $rssResponse = [xml](Invoke-WebRequest $rssUrl)
        $NewReleaseTitle = $rssResponse.rss.channel.item[0].title
        if($NewReleaseTitle.Count -ne 1){$NewReleaseTitle = $NewReleaseTitle[0]}
		$DownloadUrl = $rssResponse.rss.channel.item[0].enclosure.url
        if($DownloadUrl.Contains('?')){
            $DownloadUrl = $DownloadUrl.Substring(0,$DownloadUrl.IndexOf('?'))
        }

        if($NewReleaseTitle -ne $LastReleaseTitle){
            $DownloadUrlTelegram = $DownloadUrl
            $NewReleaseTitleTelegram = $NewReleaseTitle
            if($DownloadUrlTelegram.Contains('#')){
                $DownloadUrlTelegram = $DownloadUrlTelegram -Replace '\#', '%23'
            }
            if($NewReleaseTitleTelegram.Contains('#')){
               $NewReleaseTitleTelegram = $NewReleaseTitleTelegram -Replace '\#', '%23'
            }
            if($DownloadUrlTelegram.Contains('(')){
                $DownloadUrlTelegram = $DownloadUrlTelegram -Replace '\(', '%28'
            }
            if($NewReleaseTitleTelegram.Contains('(')){
               $NewReleaseTitleTelegram = $NewReleaseTitleTelegram -Replace '\(', '%28'
            }
            if($DownloadUrlTelegram.Contains(')')){
                $DownloadUrlTelegram = $DownloadUrlTelegram -Replace '\)', '%29'
            }
            if($NewReleaseTitleTelegram.Contains(')')){
               $NewReleaseTitleTelegram = $NewReleaseTitleTelegram -Replace '\)', '%29'
            }
            if($NewReleaseTitleTelegram.Contains('&')){
               $NewReleaseTitleTelegram = $NewReleaseTitleTelegram -Replace '\&', '%26'
            }
            try{
            $TelegramResponse = Invoke-WebRequest -Uri "https://api.telegram.org/bot$TelegramBotToken/sendMessage?chat_id=$TelegramChatId&parse_mode=markdown&text=[$NewReleaseTitleTelegram]($DownloadUrlTelegram)" -Method POST
                if($TelegramResponse.StatusCode -eq "200"){
				    Write-Host "New $ShortName! Message has successfully been sent."
                    $PodcastInfo.$ShortName.ChildNodes.Item(7).'#text' = $NewReleaseTitle
                    $PodcastInfo.Save("$ScriptPath\PodcastsConfig\" + $ShortName + ".xml")
		        }
            }
            catch{
                if($_.Exception.InnerException.Response.StatusCode.value__ -ne "200"){
			    Write-Host "An error occured when trying to send a message to Telegram."
                }
            }
        }
	#else{
	#	Write-Host "A new #shortname is not yet online." 
	#}

    #}
}

while($true){
    foreach($Podcast in $Podcasts){
        [xml]$PodcastInfo = Get-Content (".\PodcastsConfig\" + $Podcast + ".xml")
        $ShortName = $PodcastInfo.$Podcast.shortname
		Write-Host "Checking for a new episode of $ShortName..."
        if($PodcastInfo.$Podcast.userssFeed -eq "true" -or $forceRSS -eq 'true'){
            $LastReleaseTitle = $PodcastInfo.$Podcast.lastrssFeedTitle
            $rssUrl = $PodcastInfo.$Podcast.rssfeed
            CheckRSS -LastReleaseTitle $LastReleaseTitle -rssUrl $rssUrl
        }
        else{
            $Title = $PodcastInfo.$Podcast.podcastTitle
            $DecimalAmount = $PodcastInfo.$Podcast.digits
            $LastReleasedId = [int]$PodcastInfo.$Podcast.LastReleasedPodcast
            $Url = ($PodcastInfo.$Podcast.url -replace '#ID_GOES_HERE#', ("{0:D$DecimalAmount}" -f ([int]($PodcastInfo.$Podcast.LastReleasedPodcast)+1)))
            CheckURL -PodcastURL $Url -PodcastEpisodeId $LastReleasedId -PodcastTitle $Title
        }
    }
    Start-Sleep 150
}