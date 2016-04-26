Db = require 'db'
Http = require 'http'
Timer = require 'timer'
App = require 'app'

API_KEY = "67557EB2FBDA2BED"
GOT_ID = 121361 #Game of Thrones
LOST_ID = 73739 #LOST
SEASON_NR = 6
SERIES_ID = GOT_ID

exports.onInstall = exports.onUpgrade = exports.updateEpisodes = !->
	for episodeNr in [1..10]
		Http.get
			url: "http://thetvdb.com/api/#{API_KEY}/series/#{SERIES_ID}/default/#{SEASON_NR}/#{episodeNr}/en.xml"
			cb: ['setEpisode', episodeNr]

	# update again in a day
	Timer.cancel 'updateEpisodes'
	Timer.set (24*60*60*1000), 'updateEpisodes'

exports.setEpisode = (episodeNr, data) !->
	# called when the Http API has the result for the above request
	if data.status != '200 OK'
		log 'Error code: ' + data.status
		log 'Error msg: ' + data.error
	else
		tree = Xml.decode data.body
		result = {}

		if meta = Xml.search(tree, '*. episodename')[0]
			if (title = meta.innerText)?
				result.title = title

				if meta = Xml.search(tree, '*. overview')[0]
					if (overview = meta.innerText)?
						result.summary = overview

				if meta = Xml.search(tree, '*. firstaired')[0]
					if (airDate = meta.innerText)?
						result.airDate = airDate

				if meta = Xml.search(tree, '*. filename')[0]
					if (filename = meta.innerText)?
						result.image = 'http://www.thetvdb.com/banners/' + filename

				Db.shared.set 'episodes', episodeNr, 'info', result

exports.client_watched = (id) !->
	Db.shared.set 'episodes', id, 'watched', App.userId(), App.time()
