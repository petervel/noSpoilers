Db = require 'db'
Http = require 'http'
Timer = require 'timer'
App = require 'app'
Xml = require 'xml'
Event = require 'event'
Comments = require 'comments'
Tvdb = require 'tvdb'

# make sure we are signed in
exports.onInstall = !->
	Db.backend.set 'attempts', 0

getEpisode = (i) !->
	Tvdb.getEpisode i, (result) !->
		# still finding new episodes?
		if result
			Db.shared 'episodes', i, result
			getEpisode i + 1

# Http wrappers since those calls always land in this file
exports.getToken = !-> Tvdb.getToken()
exports.setToken = (refreshing, data) !-> Tvdb.setToken refreshing, data
exports.setEpisode = (episodeNr, cb, data) !-> Tvdb.setEpisode episodeNr, cb, data
exports.client_findShow = (name, language, cbo) !-> Tvdb.findShow name, language, cbo
exports.returnShows = (cb, data) !-> Tvdb.returnShows cb, data

exports.updateEpisodes = !->
	getEpisode 1

	# update again in a day
	Timer.cancel 'updateEpisodes'
	Timer.set (24*60*60*1000), 'updateEpisodes'

exports.client_unwatched = (id) !->
	episode = Db.shared.ref 'episodes', id
	episode.set 'watched', App.userId(), null

exports.client_watched = (id) !->
	episode = Db.shared.ref 'episodes', id
	watchedBy = episode.ref 'watched'
	sendTo = (+k for k,v of watchedBy.get() when not App.userIsMock(+k))
	Comments.post
		s: 'watched'
		store: ['episodes', id, 'comments']
		u: App.userId()
		path: [id]
		normalPrio: sendTo
		pushText: App.userName() + " watched episode “" + episode.get('info', 'title') + "”"

	watchedBy.set App.userId(), App.time()

exports.onConfig = (config = {}, fromInstall = false) !->
	log '[config] ', JSON.stringify(config)

	loadShow +config.showId, +config.seasonNr

loadShow = (showId) !->
