#Get the path 
$ScriptPath = $PSScriptRoot
$Podcasts = Get-ChildItem $ScriptPath/PodcastsConfig/*.xml | ForEach-Object {$_.BaseName}

#Load the config
[xml]$Config = Get-Content "$ScriptPath/config.xml"

#Telegram API Data
$TelegramEnabled = $Config.config.TelegramSettings.EnableTelegram
$TelegramBotToken = $Config.config.TelegramSettings.BotToken
$TelegramChatId = $Config.config.TelegramSettings.ChatID

#Discord API Data
$DiscordEnabled = $Config.config.DiscordSettings.EnableDiscord
$DiscordBotToken = $Config.config.DiscordSettings.token
$DiscordChannelId = $Config.config.DiscordSettings.channel_id

#BotSettings
$ForceRSS = $Config.config.BotSettings.ForceRSS
$SaveFiles = $Config.config.BotSettings.SaveFiles
$SavePath = $Config.config.BotSettings.SavePath

#Title Storage
$TitlesStorage = $Config.config.BotSettings.TitleStorage

#Disable Showing Progress of Invoke-Webrequest
#SilentlyContinue = Don't show progress
#Continue = Show progress
$ProgressPreference = 'SilentlyContinue'

#Headers used in the script
$HeadersNoCache = @{"Cache-Control"="no-cache"}
$HeadersJson = @{"Cache-Control"="no-cache"; "Content-Type"="application/json"}

if(!(Test-Path $SavePath)){
	$null = New-Item -ItemType Directory -Force -Path $SavePath
}
if(!(Test-Path $TitlesStorage)){
	$null = New-Item -ItemType File -Force -Path $TitlesStorage
	if($null -eq (Get-Content $TitlesStorage)){
		[System.IO.File]::WriteAllText([System.String]$TitlesStorage, ("Placeholder Title" + [System.Environment]::NewLine))
	}
}

function Read-RSS{
	param(
		[Parameter(Mandatory=$true)][System.Uri]$RssUrl,
		[Parameter(Mandatory=$true)][System.Uri]$ShortName
	)

	try{
		$RssResponse = (Invoke-RestMethod $RssUrl -Headers $HeadersNoCache)
		if($ShortName -eq 'KTRA'){
			[System.Array]::Reverse($RssResponse)
		}
		$RssResponse = $RssResponse | Select-Object -First 1
		$RssReleaseTitle = $RssResponse.title | Select-Object -First 1

		$AllTitles = Get-Content $TitlesStorage
		if(!($AllTitles.Contains($RssReleaseTitle))){
			[System.Uri]$RssDownloadUrl = $RssResponse.enclosure.url | Select-Object -First 1
			[System.Uri]$RssImageUrl = $RssResponse.image.href | Select-Object -First 1

			if($RssDownloadUrl.Query.Length -ge 1){
				[System.Uri]$RssDownloadUrl = $RssDownloadUrl.AbsoluteUri.Replace($RssDownloadUrl.Query,'')
			}

			if($RssImageUrl.Query.Length -ge 1){
				[System.Uri]$RssImageUrl = $RssImageUrl.AbsoluteUri.Replace($RssImageUrl.Query,'')
			}

			Send-Telegram -PodcastTitle $RssReleaseTitle -PodcastDownloadUrl $RssDownloadUrl
			Send-Discord -PodcastTitle $RssReleaseTitle -PodcastDownloadUrl $RssDownloadUrl -DiscordImageUrl $RssImageUrl
			Get-File -PodcastDownloadUrl $RssDownloadUrl
			[System.IO.File]::AppendAllLines([System.String]$TitlesStorage, [System.String[]]($RssReleaseTitle))
		}
		#return $true
	}
	catch{
		Write-Host "Something went wrong with checking the RSS feed."
	}
}

function Get-Url {
	param(
		[Parameter(Mandatory=$true)][System.String]$PodcastTitle,
		[Parameter(Mandatory=$true)][System.Int64]$PodcastEpisodeId,
		[Parameter(Mandatory=$true)][System.Uri]$PodcastUrl
	)
	$PodcastEpisodeId++

	try{
		$PodcastUrlResponse = Invoke-WebRequest -Uri $PodcastURL -ErrorAction Ignore -DisableKeepAlive -UseBasicParsing -Method Head -Headers $HeadersNoCache
		try{
			Send-Telegram -PodcastTitle $PodcastTitle -PodcastEpisodeId $PodcastEpisodeId -PodcastDownloadUrl $PodcastUrl
			Send-Discord -PodcastTitle $PodcastTitle -PodcastEpisodeId $PodcastEpisodeId -PodcastDownloadUrl $PodcastUrl
			Get-File -PodcastDownloadUrl $RssDownloadUrl
			[System.IO.File]::AppendAllLines([System.String]$TitlesStorage, [System.String[]]($RssReleaseTitle))
			
			# Saving xml file
			[System.Int64]$NewPodcastId = $PodcastEpisodeId
			$PodcastInfo.$ShortName.ChildNodes.Item(1).'#text' = ($NewPodcastId++).ToString()
			$PodcastInfo.Save("$ScriptPath/PodcastsConfig/" + $ShortName + ".xml")
		}
		catch{
			Write-Host "Something went wrong when sending a message or downloading the file"
		}
	}
	catch{
		if($_.Exception.Response.StatusCode.value__ -eq "404"){
			Write-Host "$ShortName $PodcastEpisodeId is not yet online." 
		}
	}
}

function Get-File {
	param(
		[Parameter(Mandatory=$true)][System.Uri]$PodcastDownloadUrl
	)

	if($SaveFiles){
		$FileName = $PodcastDownloadUrl.Segments | Select-Object -Last 1
		$DownloadUrl = $PodcastDownloadUrl.AbsoluteUri
		$FullSavePath = ("$SavePath" + '/' + "$FileName")
		Write-Host ("Downloading " + $FileName  + " to $FullSavePath")
		Invoke-WebRequest -Uri $DownloadUrl -OutFile $FullSavePath -Headers $HeadersNoCache
	}
}

function Send-Telegram {
	param(
		[Parameter(Mandatory=$true)][System.String]$PodcastTitle,
		[Parameter(Mandatory=$false)][System.Int64]$PodcastEpisodeId,
		[Parameter(Mandatory=$true)][System.Uri]$PodcastDownloadUrl
	)
	if($TelegramEnabled){
		try{
			$TelegramTitle = [System.Web.HttpUtility]::UrlEncode($PodcastTitle)
			if(($PodcastEpisodeId.Length -ge 1) -and ($PodcastEpisodeId -ne 0)){
				$TelegramTitle = [System.Web.HttpUtility]::UrlEncode($PodcastTitle + ("{0:D$DecimalAmount}" -f ([System.Int64]($PodcastEpisodeId))))
			}
			$TelegramUrl = $PodcastDownloadUrl.AbsoluteUri
			$TelegramUrl = [System.Web.HttpUtility]::UrlEncode($TelegramUrl)
			$TelegramResponse = Invoke-WebRequest -Method Post -Headers $HeadersNoCache -Uri "https://api.telegram.org/bot$TelegramBotToken/sendMessage?chat_id=$TelegramChatId&parse_mode=markdown&text=[$TelegramTitle]($TelegramUrl)"
		}
		catch{
			$_.Exception
		}
	}
}

function Send-Discord {
	param(
		[Parameter(Mandatory=$true)][System.String]$PodcastTitle,
		[Parameter(Mandatory=$false)][System.Int64]$PodcastEpisodeId,
		[Parameter(Mandatory=$true)][System.Uri]$PodcastDownloadUrl,
		[Parameter(Mandatory=$false)][System.Uri]$DiscordImageUrl
	)
	if($DiscordEnabled){
		try{
			$DiscordJsonPayload = $null
			$DiscordTitle = [System.Web.HttpUtility]::UrlDecode($PodcastTitle)
			if(($PodcastEpisodeId.Length -ge 1) -and ($PodcastEpisodeId -ne 0)){
				$DiscordTitle = [System.Web.HttpUtility]::UrlDecode($PodcastTitle + ("{0:D$DecimalAmount}" -f ([System.Int64]($PodcastEpisodeId))))
			}
			$DiscordUrl = $PodcastDownloadUrl.AbsoluteUri
			if($null -eq $DiscordImageUrl){
				[System.Uri]$DiscordImageUrl = "https://dyonr.nl/hs_discord_logo.png"
			}
			$DiscordImageUrl = $DiscordImageUrl.AbsoluteUri

			$DiscordJsonPayload = @{
				embeds = @(
					@{
						title = ("$DiscordTitle")
						description = ("$DiscordTitle")
						url = "$DiscordUrl"
						color = '16742144'
						thumbnail = @{
							url = $DiscordImageUrl
						}
					}
				)
			} | ConvertTo-Json  -Depth 10
			$DiscordResponse = Invoke-WebRequest -Uri "https://discord.com/api/webhooks/$DiscordChannelId/$DiscordBotToken" -Method Post -Body ($DiscordJsonPayload) -Headers $HeadersJson
		}
		catch{
			$_.Exception
		}
	}
}

foreach($Podcast in $Podcasts){
	[xml]$PodcastInfo = Get-Content ("$ScriptPath/PodcastsConfig/" + $Podcast + ".xml")
	$ShortName = $PodcastInfo.$Podcast.shortName
	$LastReleasedId = $null
	$PodcastEpisodeId = $null
	Write-Host "$ShortName"
	if($PodcastInfo.$Podcast.userssFeed){
		[System.Uri]$RssUrl = $PodcastInfo.$Podcast.rssfeed
		Read-RSS -RssUrl $RssUrl -ShortName $ShortName
	}
	else{
		$Title = $PodcastInfo.$Podcast.podcastTitle
		$DecimalAmount = $PodcastInfo.$Podcast.digits
		$LastReleasedId = [System.Int64]$PodcastInfo.$Podcast.LastReleasedPodcast
		[System.Uri]$Url = ($PodcastInfo.$Podcast.url -replace '#ID_GOES_HERE#', ("{0:D$DecimalAmount}" -f ([System.Int64]($PodcastInfo.$Podcast.LastReleasedPodcast)+1)))
		Get-Url -PodcastTitle $Title -PodcastEpisodeId $LastReleasedId -PodcastUrl $Url
	}
}