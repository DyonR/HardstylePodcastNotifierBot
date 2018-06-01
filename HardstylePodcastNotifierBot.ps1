#Get the path 
$ScriptPath = $PSScriptRoot
$Podcasts = Get-ChildItem $ScriptPath\PodcastsConfig\*.xml | ForEach-Object {$_.BaseName}

#Load the config
[xml]$Config = Get-Content "$ScriptPath\config.xml"

#Telegram API Data
$TelegramBotToken = $Config.config.TelegramSettings.BotToken
$TelegramChatId = $Config.config.TelegramSettings.ChatID

#BotSettings
$ForceRSS = $Config.config.BotSettings.ForceRSS
$SaveFiles = $Config.config.BotSettings.SaveFiles
$SavePath = $Config.config.BotSettings.SavePath

#Disable Showing Progress of Invoke-Webrequest
#SilentlyContinue = Don't show progress
#Continue = Show progress
$ProgressPreference = 'SilentlyContinue'

if(!(Test-Path $SavePath)){
    New-Item -ItemType Directory -Force -Path $SavePath
}

function CheckURL{

    param(
        [Parameter(Mandatory=$true)][string]$PodcastURL,
        [Parameter(Mandatory=$true)][int]$PodcastEpisodeId,
        [Parameter(Mandatory=$true)][string]$PodcastTitle
    )

    $PodcastEpisodeId++
    try{
        $PodcastUrlResponse = Invoke-WebRequest -Uri $PodcastURL -ErrorAction Ignore -DisableKeepAlive -UseBasicParsing -Method Head
        try{
			$TelegramResponse = Invoke-WebRequest -Uri "https://api.telegram.org/bot$TelegramBotToken/sendMessage?chat_id=$TelegramChatId&parse_mode=markdown&text=[$PodcastTitle$PodcastEpisodeId]($PodcastURL)" -Method POST
			if($TelegramResponse.StatusCode -eq "200"){
				Write-Host "New $ShortName Episode! Message has successfully been sent."
                $OriginalName = [System.IO.Path]::GetFileName($PodcastURL)
                try{
					if($SaveFiles -eq $true){
						Write-Host "Downloading $OriginalName"
						Invoke-WebRequest -Uri $PodcastURL -OutFile "$SavePath\$OriginalName"
						Write-Host "Download finished"
					}
                }
				catch{
					Write-Output "Failed to download $OriginalName`: `n$PodcastURL`n" | Out-File -Append "$SavePath\Failed Downloads.txt"
				}
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
    try{
        $rssResponse = [xml](Invoke-WebRequest $rssUrl)
        if($ShortName -eq "KTRA"){
            $NewReleaseTitle = ($rssResponse.rss.channel.item | Select-Object -Last 1).title
            $DownloadUrl = ($rssResponse.rss.channel.item | Select-Object -Last 1).origEnclosureLink
        }
        else{
            $NewReleaseTitle = $rssResponse.rss.channel.item.title | Select-Object -First 1
            $DownloadUrl = $rssResponse.rss.channel.item.enclosure.url | Select-Object -First 1
        }

        if($NewReleaseTitle.Count -ne 1){$NewReleaseTitle = $NewReleaseTitle[0]}

        if($DownloadUrl.Contains('?')){
            $DownloadUrl = $DownloadUrl.Substring(0,$DownloadUrl.IndexOf('?'))
        }

        if($NewReleaseTitle.Contains('#')){
            $NewReleaseTitle = $NewReleaseTitle -Replace '\#', '%23'
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
            if($NewReleaseTitleTelegram.Contains('|')){
                $NewReleaseTitleTelegram = $NewReleaseTitleTelegram -Replace '\|', '%7c'
            }

            $OriginalName = [System.IO.Path]::GetFileName($DownloadURL)

            try{
            $TelegramResponse = Invoke-WebRequest -Uri "https://api.telegram.org/bot$TelegramBotToken/sendMessage?chat_id=$TelegramChatId&parse_mode=markdown&text=[$NewReleaseTitleTelegram]($DownloadUrlTelegram)" -Method POST
                if($TelegramResponse.StatusCode -eq "200"){
				    Write-Host "New $ShortName! Message has successfully been sent."
                    try{
                        if($SaveFiles -eq $true){
                            Write-Host "Downloading $OriginalName"
					        Invoke-WebRequest -Uri $DownloadUrlTelegram -OutFile "$SavePath\$OriginalName"
                            Write-Host "Download finished"
                        }
                    }
				    catch{
    					Write-Output "Failed to download $OriginalName`: `n$DownloadUrlTelegram`n" | Out-File -Append "$SavePath\Failed Downloads.txt"
				    }
                    $PodcastInfo.$ShortName.ChildNodes.Item(7).'#text' = "$NewReleaseTitle"
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
        #	Write-Host "A new $ShortName is not yet online." 
        #}
    }
	catch{
		Write-Host "Error obtaining the RSS feed." 
	}
}

while($true){
    foreach($Podcast in $Podcasts){
        [xml]$PodcastInfo = Get-Content ("$ScriptPath\PodcastsConfig\" + $Podcast + ".xml")
        $ShortName = $PodcastInfo.$Podcast.shortName
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
    Get-Date -Format "HH:mm"
    Start-Sleep 60
}