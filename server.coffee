Db = require 'db'
Http = require 'http'
Timer = require 'timer'
App = require 'app'
Xml = require 'xml'

API_KEY = "67557EB2FBDA2BED"
SERIES_ID = 121361
SEASON_NR = 6

exports.onUpgrade = !->
	loadEpisodes()

loadEpisodes = !->
	for episodeNr in [1..10]
		Http.get
			url: "http://thetvdb.com/api/#{API_KEY}/series/#{SERIES_ID}/default/#{SEASON_NR}/#{episodeNr}/en.xml"
			cb: ['setEpisode', episodeNr]

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

				if meta = Xml.search(tree, '*. filename')[0]
					if (filename = meta.innerText)?
						result.image = 'http://www.thetvdb.com/banners/' + filename

				Db.shared.set 'episodes', episodeNr, result

#exports.client_add = (title) !->
#	id = Db.shared.incr 'maxId'
#	episode = title: title
#	Db.shared.set 'episodes', id, episode

exports.client_seen = (id) !->
	Db.shared.set 'episodes', id, 'seen', App.userId(), true
