# (Hardstyle) Podcast Notifier Bot
This bot sends a message to a Telegram channel if a new Hardstyle Podcast has been posted.
A new podcast is detected by URL-guessing, or by checking the RSS feed.
If you want to be kept up-to-date with the Hardstyle Podcast releases, you can join [this Telegram channel](https://t.me/HardstylePodcastNotifier)!

Most podcasts URLs just have the episode number somehwere in the URL, so if the URL of one episode is known, it is possible to guess other URLs. This script will fail if an artists starts using a new service for his podcasts, a special is uploaded (which adds in most cases extra stuff to the URL, for example 'Yearmix 2017') or when an artists changed the filename, by adding or removing a 0 or a _.

This bot supports RSS feeds and URL-guessing. This can be configured in a podcast config file in the PodcastsConfig.

If you use this script, do not forget to edit the exampleconfig.xml and rename it to config.xml