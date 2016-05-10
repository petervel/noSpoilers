Db = require 'db'
Http = require 'http'
Timer = require 'timer'
App = require 'app'
Xml = require 'xml'
Event = require 'event'
Comments = require 'comments'
Tvdb = require 'tvdb'

currentShow = -> Db.shared.ref 'shows', Db.shared.get 'cfg', 'showId'

# make sure we are signed in
exports.onInstall = !->
	Tvdb.onInstall()

exports.onUpgrade =!->
	if not Db.shared.get('token') and Db.backend.get('token')
		Db.shared.set 'token', Db.backend.get('token')

exports.client_setLanguage = (language) !->
	Db.shared.set 'cfg', 'language', language

exports.client_setSeason = (season) !->
	log 'setting season ', season
	Db.shared.set 'cfg', 'season', season

exports.client_watched = (episodeNr) !->
	seasonNr = Db.shared.peek 'cfg', 'season'
	episode = currentShow().ref 'episodes', seasonNr, episodeNr
	exports.loadEpisode episode.peek 'id'
	watchedBy = episode.ref 'watched'
	sendTo = (+k for k,v of watchedBy.get() when not App.userIsMock(+k))
	Comments.post
		s: 'watched'
		store: ['shows', Db.shared.peek('cfg', 'showId'), 'episodes', seasonNr, episodeNr, 'comments']
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
	Db.shared.set 'cfg', config
	Tvdb.loadShow()

sanityCheckResponse = (data) ->
	# hack to deal with issues
	if typeof data isnt 'object'
		log 'missing response data, assume it was ok...', data
		data = status: '200 OK', body: data
	data

# Http wrappers since those calls always land in this file
exports.getToken = !-> Tvdb.getToken()
exports.setToken = (refreshing, data) !-> Tvdb.setToken refreshing, sanityCheckResponse data

exports.loadEpisode = (id) !-> Tvdb.loadEpisode id
exports.setEpisode = (data) !-> Tvdb.setEpisode sanityCheckResponse data

exports.setShow = (data) !->
	Tvdb.setShow sanityCheckResponse data

exports.setEpisodes = (data) !-> Tvdb.setEpisodes sanityCheckResponse data
