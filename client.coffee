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

exports.render = !->
	if episodeId = Page.state.get(0)
		renderEpisode +episodeId
	else
		renderMainPage()

renderMainPage = !->
	Dom.img !->
		Dom.style display: 'block', width: '100%', margin: 'auto'
		Dom.prop 'src', Db.shared.get 'banner'

	deltas = []
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
					airDate = new Date tmp[0], (+tmp[1] - 1), (+tmp[2] + 1)
					delta = App.date().getTime() - airDate.getTime()
					fontWeight = if delta > 0 and delta < (7*24*60*60*1000) then 'bold' else 'inherit'
					deltas.push delta
					Dom.style Flex: 1, fontWeight: fontWeight
					Dom.text episode.get 'info', 'title'

					Dom.span !->
						Dom.style color: '#ddd', fontSize: 'x-small', margin: '0 5px'
						Dom.text "(" + episode.get('info', 'airDate') + ")"

				Dom.div !->
					Dom.style padding: '0 5px', width: '30px'
					Event.renderBubble [episode.key()]

				renderWatched episode.ref 'watched'

		, (episode) -> +episode.key()

renderEpisode = (id) !->
	episode = Db.shared.ref 'episodes', id
	info =  episode.ref 'info'
	watchedBy = episode.ref 'watched'

	Page.setTitle info.get 'title'

	###
	Dom.div !->
		Dom.text "unwatch"
		Dom.onTap !->
			Server.send 'unwatched', id
			Page.nav ''
	###
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

exports.renderSettings = !->
	#if Db.shared
	#	Dom.div !-> "You can't change the tv show this app is showing. Start a new one for a different show."
	#	return

	cfg = Db.shared.get('cfg') || {}

	language = Obs.create()
	showName = Obs.create ''
	shows = Obs.create()


	findShow = !->
		Server.call 'findShow', showName.peek(), language.peek(), (result) !->
			# TODO: shouldn't .set just clear existing values in this hash? else it'd be .merge right?
			shows.set null # clear old search results
			#Modal.show "before: " + JSON.stringify showsInfo.get()
			#Modal.show "setting value: " + JSON.stringify result
			shows.set result
			#Modal.show "after: " + JSON.stringify showsInfo.get()

	Form.segmented
		name: 'language'
		value: 'en'
		segments: ['en', 'English', 'nl', 'Dutch']
		onChange: (v) !->
			language.set v
			findShow()

	Form.box !->
		Dom.style width: '100%', boxSizing: 'border-box', border: '1px solid transparent'

		selectedIndex = Obs.create()

		showId = Form.hidden 'showId'

		Obs.observe !->
			showId.value shows.get 'shows', selectedIndex.get(), 'id'

		Obs.observe !->
			if showName.get()?.length >= 3
				Obs.onTime 500, !-> findShow()

		Form.input
			name: '_showName'
			text: 'tv show'
			value: cfg.showName
			style: Flex: 1
			onChange: (val) !-> showName.set val

		Obs.observe !->
			return if not shows.get() # nothing searched

			if shows.count().get() is 0
				Dom.div !->
					Dom.style margin: '0 5px'
					Dom.text "No matches found."
			else
				Dom.div !->
					Dom.style margin: '0 5px'
					Dom.text "#{shows.count().get()} matches:"
				Dom.div !->
					Dom.style maxHeight: '300px', overflow: 'auto'
					shows.iterate (show) !->
						Ui.item !->
							Dom.style position: 'relative'
							Obs.observe !->
								if selectedIndex.get() is show.key()
									Dom.style border: "2px solid #{App.colors().highlight}", borderRadius: '3px'
								else
									Dom.style border: '2px solid transparent'
							Dom.div !->
								Dom.style
									position: 'absolute'
									zIndex: 1
									opacity: 0.1
									left: 0
									top: 0
									bottom: 0
									right: 0
									background: "transparent url(http://www.thetvdb.com/banners/#{show.get 'banner'}) no-repeat center"

							Dom.div !->
								Dom.style zIndex: 2
								Dom.div !->
									Dom.style fontWeight: 'bold', fontSize: '12pt', margin: '5px 0'
									Dom.text show.get 'seriesName'
								Dom.div !->
									Dom.style fontStyle: 'italic', color: '#aaa', fontSize: '10pt', maxHeight: '80px', overflow: 'hidden'
									Dom.text show.get 'overview'
							Dom.onTap !->
								if selectedIndex.peek() isnt show.key()
									selectedIndex.set show.key()
								else
									selectedIndex.set null
									showId.value null # why is this needed?

		Form.condition !->
			return "No tv show selected" if not showId.value()

	Dom.div !->
		Dom.style height: '20px'
