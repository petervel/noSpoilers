Comments = require 'comments'
Db = require 'db'
Dom = require 'dom'
Modal = require 'modal'
Obs = require 'obs'
App = require 'app'
Page = require 'page'
Server = require 'server'
Ui = require 'ui'
Xml = require 'xml'
Event = require 'event'
Icon = require 'icon'
Form = require 'form'
Config = require 'config'
Tvdb = require 'tvdb'

exports.render = !->
	if episodeNr = Page.state.get(0)
		renderEpisode +episodeNr
	else
		renderMainPage()

renderMainPage = !->
	#Page.setTitle Db.shared.get('show', 'seriesName') ? "No Spoilers!"
	if image = Db.shared.get 'show', 'nsImage'
		Dom.img !->
			Dom.style display: 'block', width: '100%', margin: 'auto'
			Dom.prop 'src', image

	Db.shared.iterate 'show', 'episodes', Db.shared.get('cfg', 'season'), (episode) !->
			renderEpisodeItem episode
		, (episode) -> +episode.key()

renderEpisodeItem = (episode) !->
	seasonNr = +Db.shared.peek('cfg', 'season')
	Ui.item !->
		Dom.onTap !->
			goToEpisode = !-> Page.nav episode.key()
			if episode.get 'watched', App.userId()
				goToEpisode()
			else
				Modal.confirm "SPOILERS AHEAD!", "Are you sure you have already watched this episode?", !->
					Server.sync 'watched', episode.key(), !->
						episode.set 'watched', App.userId(), true
					goToEpisode()

		Dom.style Box: 'horizontal', alignItems: 'center'

		Dom.div !->
			Dom.style minWidth: '20px', textAlign: 'right', marginRight: '10px'
			Dom.text episode.key() + '.'

		if episode.get('watched', App.userId()) and image = episode.get('nsImage')
			Dom.img !->
				Dom.style margin: '0 10px', display: 'block', height: '36px', width: '64px', borderRadius: '5px'
				Dom.prop 'src', image
		else
			Dom.div !->
				Dom.style margin: '0 10px', display: 'block', height: '36px', width: '64px', borderRadius: '5px', background: '#ddd', textAlign: 'center', lineHeight: '36px', color: '#fff'
				Dom.text "?"

		Dom.div !->
			tmp = episode.get('firstAired')?.split('-')
			airDate = new Date tmp[0], (+tmp[1] - 1), (+tmp[2] + 1)
			delta = App.date().getTime() - airDate.getTime()
			fontWeight = if delta > 0 and delta < (7*24*60*60*1000) then 'bold' else 'inherit'

			Dom.style Flex: 1, fontWeight: fontWeight
			Dom.text episode.get 'episodeName'

			Dom.span !->
				Dom.style color: '#ddd', fontSize: 'x-small', margin: '0 5px'
				Dom.text "(" + episode.get('firstAired') + ")"

		Dom.div !->
			Dom.style padding: '0 5px', width: '30px'
			Event.renderBubble [seasonNr, +episode.key()]

		renderWatched episode.ref 'watched'


renderEpisode = (episodeNr) !->
	seasonNr = Db.shared.peek('cfg', 'season')
	episode = Db.shared.ref 'show', 'episodes', seasonNr, episodeNr
	#Modal.show JSON.stringify episode.get()
	#info =  episode.ref 'info'
	watchedBy = episode.ref 'watched'

	Page.setTitle episode.get 'episodeName'

	###
	Dom.div !->
		Dom.text "unwatch"
		Dom.onTap !->
			Server.send 'unwatched', episodeNr
			Page.nav ''
	###
	Dom.h1 !->
		Dom.style textAlign: 'center'
		Dom.text episode.get 'episodeName'

	Dom.div !->
		Dom.style textAlign: 'center'
		renderWatched watchedBy

	if image = episode.get 'nsImage'
		Dom.img !->
			Dom.style margin: '20px auto', display: 'block'
			Dom.prop 'src', image

	if airDate = episode.get 'firstAired'
		Dom.div !->
			Dom.style fontStyle: 'italic', fontSize: 'small'
			Dom.text airDate

	if overview = episode.get 'overview'
		Ui.card !->
			Dom.text overview

	Comments.enable
		invertBar: false
		onSend: (comment) ->
			comment.lowPrio = 'all'
			comment.normalPrio = (k for k,v of watchedBy.get())
			false
		store: ['show', 'episodes', seasonNr, episodeNr, 'comments']
		path: [seasonNr, episodeNr]
		messages:
			# the key is the `s` key.
			watched: (c) -> App.userName(c.u) + " watched this episode"

renderWatched = (watchedBy) !->
	watchedCount = Obs.create 0
	Obs.observe !->
		watchedBy.iterate (watchedTime) !->
			return if App.userIsMock(+watchedTime.key())
			watchedCount.incr()
			Obs.onClean !->
				watchedCount.incr(-1)

	Dom.div !->
		colour = if watchedBy.get(App.userId()) then App.colors().highlight else '#ddd'
		Dom.style color: colour, borderRadius: '3px', minWidth: '30px', padding: '15px 10px', margin: '-10px'
		Icon.render
			data: 'eye'
			size: 20
			color: colour

		Dom.text watchedCount.get()
		Dom.onTap !->
			Modal.show "Watched by:", !->
				if watchedCount.get()
					watchedBy.iterate (watchedTime) !->
							userId = +watchedTime.key()
							return if App.userIsMock(userId)
							Ui.item !->
								if userId is App.userId()
									Dom.style fontWeight: 'bold'
								Ui.avatar
									key: App.userAvatar(userId)
									onTap: !-> App.showMemberInfo(userId)
								Dom.div !->
									Dom.style marginLeft: '10px', Flex: 1
									Dom.text App.userName(userId)
						, (watchedTime) -> -watchedTime.get()
				else
					Dom.div !->
						Dom.style padding: '5px'
						Dom.text "no one yet"


exports.renderSettings = !->
	Config.render()

# wrapper
exports.returnShows = (cb, data) !-> Tvdb.returnShows cb, data