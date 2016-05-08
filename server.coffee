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
	Tvdb.onInstall()

exports.client_setLanguage = (language) !->
	Db.shared.set 'cfg', 'language', language

exports.client_setSeason = (season) !->
	log 'setting season ', season
	Db.shared.set 'cfg', 'season', season

exports.client_watched = (episodeNr) !->
	seasonNr = Db.shared.peek 'cfg', 'season'
	episode = Db.shared.ref 'show', 'episodes', seasonNr, episodeNr
	Tvdb.loadEpisode episode.peek 'id'
	watchedBy = episode.ref 'watched'
	sendTo = (+k for k,v of watchedBy.get() when not App.userIsMock(+k))
	Comments.post
		s: 'watched'
		store: ['show', 'episodes', seasonNr, episodeNr, 'comments']
		u: App.userId()
		path: [seasonNr, episodeNr]
		normalPrio: sendTo
		pushText: App.userName() + " watched episode “" + episode.get('info', 'title') + "”"

	watchedBy.set App.userId(), App.time()

exports.client_unwatched = (id) !->
	episode = Db.shared.ref 'episodes', id
	episode.set 'watched', App.userId(), null

exports.onConfig = (config = {}, fromInstall = false) !->
	log '[config] ', JSON.stringify(config)
	Db.shared.set 'cfg', 'season', config.season

# Http wrappers since those calls always land in this file
exports.getToken = !-> Tvdb.getToken()
exports.setToken = (refreshing, data) !-> Tvdb.setToken refreshing, data
exports.setEpisode = (episodeNr, cb, data) !-> Tvdb.setEpisode episodeNr, cb, data
exports.client_findShow = (name, cbo) !-> Tvdb.findShow name, cbo
exports.returnShows = (cb, data) !-> Tvdb.returnShows cb, data
exports.setShow = (data) !->
	Tvdb.setShow data
	App.setTitle Db.shared.get('show', 'seriesName') ? App.title()
exports.setEpisodes = (data) !-> Tvdb.setEpisodes data
exports.client_loadShow = (id) !->
	Db.shared.set 'cfg', 'showId', id
	Tvdb.loadShow id
loadShow = (showId) !-> Tvdb.loadShow showId
