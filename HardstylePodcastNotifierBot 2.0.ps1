#Get the path 
#$ScriptPath = $PSScriptRoot
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

			if($DiscordEnabled){
				Send-Discord -PodcastTitle $RssReleaseTitle -PodcastDownloadUrl $RssDownloadUrl -DiscordImageUrl $RssImageUrl
			}
			if($TelegramEnabled){
				Send-Telegram -PodcastTitle $RssReleaseTitle -PodcastDownloadUrl $RssDownloadUrl
			}
			if($SaveFiles){
				if(!($ShortName -eq "Brennan" -or $ShortName -eq "GlobalDedication")){
				Get-File -PodcastDownloadUrl $RssDownloadUrl
				}
			}
			[System.IO.File]::AppendAllLines([System.String]$TitlesStorage, [System.String[]]($RssReleaseTitle))
		}
		#return $true
	}
	catch{
		Write-Host "Something went wrong with checking the RSS feed."
	}
}

function Get-File {
	param(
		[Parameter(Mandatory=$true)][System.Uri]$PodcastDownloadUrl
	)

	$FileName = $PodcastDownloadUrl.Segments | Select-Object -Last 1
	$DownloadUrl = $PodcastDownloadUrl.AbsoluteUri
	$FullSavePath = ("$SavePath" + '/' + "$FileName")

	Invoke-WebRequest -Uri $DownloadUrl -OutFile $FullSavePath -Headers $HeadersNoCache
}

function Send-Telegram {
	param(
		[Parameter(Mandatory=$true)][string]$PodcastTitle,
		[Parameter(Mandatory=$false)][int]$PodcastEpisodeId,
		[Parameter(Mandatory=$true)][System.Uri]$PodcastDownloadUrl
	)
	
	$TelegramTitle = [System.Web.HttpUtility]::UrlEncode($PodcastTitle)
	#$TelegramEpisodeId
	$TelegramUrl = $PodcastDownloadUrl.AbsoluteUri
	$TelegramUrl = [System.Web.HttpUtility]::UrlEncode($TelegramUrl)
	$TelegramResponse = Invoke-WebRequest -Method Post -Headers $HeadersNoCache -Uri "https://api.telegram.org/bot$TelegramBotToken/sendMessage?chat_id=$TelegramChatId&parse_mode=markdown&text=[$TelegramTitle]($TelegramUrl)"
}

function Send-Discord {
	param(
		[Parameter(Mandatory=$true)][string]$PodcastTitle,
		[Parameter(Mandatory=$false)][int]$PodcastEpisodeId,
		[Parameter(Mandatory=$true)][System.Uri]$PodcastDownloadUrl,
		[Parameter(Mandatory=$false)][System.Uri]$DiscordImageUrl
	)

	$DiscordJsonPayload = $null
	$DiscordTitle = [System.Web.HttpUtility]::UrlDecode($PodcastTitle)
	#$DiscordEpisodeId
	$DiscordUrl = $PodcastDownloadUrl.AbsoluteUri
	if($null -eq $DiscordImageUrl){
		[System.Uri]$DiscordImageUrl = "https://dyonr.nl/hs_discord_logo.png"
	}
	$DiscordImageUrl = $DiscordImageUrl.AbsoluteUri

	$DiscordJsonPayload = @{
		embeds = @(
			@{
				title = ("$DiscordTitle" + "$DiscordEpisodeId")
				description = ("$DiscordTitle" + "$DiscordEpisodeId")
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

foreach($Podcast in $Podcasts){
	[xml]$PodcastInfo = Get-Content ("$ScriptPath/PodcastsConfig/" + $Podcast + ".xml")
	$ShortName = $PodcastInfo.$Podcast.shortName
	Write-Host "$ShortName"
	[System.Uri]$RssUrl = $PodcastInfo.$Podcast.rssfeed
	Read-RSS -RssUrl $RssUrl -ShortName $ShortName
}