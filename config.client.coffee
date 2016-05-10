Db = require 'db'
Obs = require 'obs'
Server = require 'server'
Form = require 'form'
Dom = require 'dom'
Ui = require 'ui'
App = require 'app'
Tvdb = require 'tvdb'

exports.render = !->
	#if Db.shared
	#	Dom.div !-> "You can't change the tv show this app is showing. Start a new one for a different show."
	#	return
	cfg = Obs.create Db.shared?.peek('cfg') ? {} # the config
	cfg.set 'season', null # TODO: hack

	selectedShow = Obs.create() # Db.shared?.get('shows', cfg.peek 'showId')

	showName = Obs.create selectedShow.peek('seriesName') ? ''
	shows = Obs.create {}

	loading = Obs.create false
	searched = Obs.create false

	language = Obs.create cfg.language ? 'en' # default to English

	Form.box !->
		Form.condition !->
			return "No tv show selected" if not selectedShow.get()
			return "No season selected" if not cfg.get 'season'

		Dom.div !->
			Obs.observe !->
				showId = Form.hidden 'showId'
				showId.value +selectedShow.get('id')

				Dom.style display: if selectedShow.get() then 'none' else 'block'

			Form.segmented
				name: 'language'
				value: language.peek()
				segments: ['en', 'English', 'nl', 'Dutch']
				onChange: (v) !->
					language.set v
					cfg.set 'language', v

			# if a setting changes, refresh the list of shows
			Obs.observe !->
				language.get()  # subscribe
				if showName.get().length
					Obs.onTime 500, !->
						loading.set true
						Tvdb.findShow showName.peek(), language.peek(), (result) !->
							# TODO: shouldn't .set just clear existing values in this hash? else it'd be .merge right?
							shows.set {} # clear old search results
							shows.set result
							searched.set true
							loading.set false
				else
					# clear results, we are not searching atm
					shows.set {}
					searched.set false
					loading.set false

			seriesName = Db.shared?.peek 'shows', cfg.peek('showId'), 'seriesName'
			Form.input
				name: '_showName'
				text: 'tv show'
				value: seriesName
				onChange: (v) !-> showName.set v

		Obs.observe !->
			# we searched and got a response
			if searched.get()
				# not selected a show yet? show list of matches
				if not selectedShow.get()
					if loading.get()
						Dom.div !->
							Dom.style fontStyle: 'italic', fontSize: '11pt', color: '#888'
							Dom.text "loading..."
					else
						renderShowsList shows, loading, showName, selectedShow
				else
					# show selected show
					renderShowItem selectedShow, selectedShow, true

					Obs.observe !->
						switch selectedShow.get 'loadResult'
							when 'loading'
								Dom.text 'loading'
								break
							when 'failed'
								Dom.text 'failed'
								break
							when 'success'
								Dom.div !->
									Dom.style margin: '10px 0'
									Dom.text "Season:"

								seasons = []
								for k of selectedShow.get 'seasons'
									seasons.push k
									seasons.push k

								Form.segmented
									name: 'season'
									value: seasons[seasons.length - 1] ? 0 # autoselect latest season
									segments: seasons
									onChange: (v) !->
										cfg.set 'season', v
								Obs.onClean !->
									cfg.set 'season', null

renderShowsList = (shows, loading, showName, selectedShow) !->
	Obs.observe !->
		empty = shows.count().get() is 0
		Dom.div !->
			Dom.style margin: '0 5px'
			if empty
				Dom.text "No matches found."
			else
				Dom.text "#{shows.count().get()} matches:"

		if not empty
			Dom.div !->
				Dom.style maxHeight: '300px', overflow: 'auto', border: '1px solid #eee', borderRadius: '3px'
				renderShowItems shows, selectedShow

renderShowItems = (shows, selectedShow) !->
	shows.iterate (show) !->
		Obs.observe !->
			Dom.animate
				create:
					opacity: 1
					initial:
						opacity: 0
				remove:
					opacity: 0
					initial:
						opacity: 1
				content: !->
					return if (sel = selectedShow.get('id')) and sel isnt show.peek 'id'
					renderShowItem show, selectedShow

renderShowItem = (show, selectedShow, selected) !->
	Ui.item !->
		Dom.style position: 'relative'
		if selected then Dom.style border: "2px solid #{App.colors().highlight}", borderRadius: '3px'

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
			if not selected
				selectedShow.set show.peek()
				selectedShow.set 'loadResult', 'loading'
				Tvdb.loadEpisodes show.peek('id'), 1, selectedShow.ref('seasons'), selectedShow.ref('loadResult')
			else
				selectedShow.set null
