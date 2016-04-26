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

exports.render = !->
	if episodeId = Page.state.get(0)
		renderEpisode +episodeId
	else
		renderMainPage()

renderMainPage = !->
	Dom.img !->
		Dom.style display: 'block', width: '100%', margin: 'auto'
		Dom.prop 'src', App.resourceUri("GoT.png")


	Db.shared.iterate 'episodes', (episode) !->
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

				if episode.get('watched', App.userId()) and image = episode.get('info', 'image')
					Dom.img !->
						Dom.style margin: '0 10px', display: 'block', height: '36px', width: '64px', borderRadius: '5px'
						Dom.prop 'src', image
				else
					Dom.div !->
						Dom.style margin: '0 10px', display: 'block', height: '36px', width: '64px', borderRadius: '5px', background: '#ddd', textAlign: 'center', lineHeight: '36px', color: '#fff'
						Dom.text "?"


				Dom.div !->
					tmp = episode.get('info', 'airDate')?.split('-')
					airDate = new Date tmp[0], tmp[1]-1, tmp[2]
					delta = App.date().getTime() - airDate.getTime()
					fontWeight = if delta > 0 and delta < (7*24*60*60*1000) then 'bold' else 'inherit'
					Dom.style Flex: 1, fontWeight: fontWeight
					Dom.text episode.get 'info', 'title'

				Dom.div !->
					Dom.style padding: '0 5px'
					Event.renderBubble [episode.key()]

				renderWatched episode.ref 'watched'

		, (episode) -> +episode.key()

renderEpisode = (id) !->
	episode = Db.shared.ref 'episodes', id
	info =  episode.ref 'info'
	watchedBy = episode.ref 'watched'

	Page.setTitle info.get 'title'

	Dom.h1 !->
		Dom.style textAlign: 'center'
		Dom.text info.get 'title'

	Dom.div !->
		Dom.style textAlign: 'center'
		renderWatched watchedBy

	if image = info.get 'image'
		Dom.img !->
			Dom.style margin: '20px auto', display: 'block'
			Dom.prop 'src', image

	if airDate = info.get 'airDate'
		Dom.div !->
			Dom.style fontStyle: 'italic', fontSize: 'small'
			Dom.text airDate

	if summary = info.get 'summary'
		Ui.card !->
			Dom.text summary

	Comments.enable
		invertBar: false
		onSend: (comment) ->
			comment.lowPrio = 'all'
			comment.normalPrio = (k for k,v of watchedBy.get())
			false
		store: ['episodes', id, 'comments']

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
		Dom.style color: colour, borderRadius: '3px', minWidth: '30px', padding: '5px 0px'
		Icon.render
			data: 'eye'
			size: 20
			color: colour

		Dom.text watchedCount.get()
		Dom.onTap !->
			Modal.show "Watched by:", !->
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
