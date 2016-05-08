Db = require 'db'
Obs = require 'obs'
Server = require 'server'
Form = require 'form'
Dom = require 'dom'
Ui = require 'ui'
App = require 'app'

exports.render = !->
	#if Db.shared
	#	Dom.div !-> "You can't change the tv show this app is showing. Start a new one for a different show."
	#	return

	showName = Obs.create ''
	shows = Obs.create {}
	selectedShow = Obs.create()
	loading = Obs.create false
	searched = Obs.create false

	Form.box !->
		Obs.observe !->
			showId = Form.hidden '_showId'
			showId.value +selectedShow.get('id')

		Dom.div !->
			Obs.observe !->
				Dom.style display: if selectedShow.get() then 'none' else 'block'

			Form.segmented
				name: '_language'
				value: 'en'
				segments: ['en', 'English', 'nl', 'Dutch']
				onChange: (v) !-> Server.sync 'setLanguage', v, !-> Db.shared.set 'cfg', 'language', v

			# if a setting changes, refresh the list of shows
			Obs.observe !->
				Db.shared.get '_language' # subscribe to changes
				if showName.get().length
					Obs.onTime 500, !->
						loading.set true
						searched.set true
						Server.call 'findShow', showName.peek(), (result) !->
							# TODO: shouldn't .set just clear existing values in this hash? else it'd be .merge right?
							shows.set {} # clear old search results
							shows.set result
							Obs.onTime 1000, !-> loading.set false # seems to be some delay??
				else
					# clear results
					shows.set null
					searched.set false

			inp = Form.input
				name: '_showName'
				text: 'tv show'
				value: Db.shared.peek 'show', 'seriesName'
				onChange: (v) !-> showName.set v

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
				if not selectedShow.get() and searched.get()
					renderShowsList shows, loading, showName, selectedShow

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
				if selectedShow.get()
					renderShowItem selectedShow, selectedShow, true

					Obs.observe !->
						Dom.div !->
							Dom.style margin: '10px 0'
							Dom.text "Season:"

						seasons = []
						for s,k of Db.shared.get 'show', 'episodes'
							seasons.push s
							seasons.push s

						Form.segmented
							name: 'season'
							value: seasons[seasons.length - 1] ? 0
							segments: seasons
		Form.condition !->
			return "No tv show selected" if not selectedShow.get()

renderShowsList = (shows, loading, showName, selectedShow) !->
	Obs.observe !->
		if loading.get()
			Dom.div !->
				Dom.style fontStyle: 'italic', fontSize: '11pt', color: '#888'
				Dom.text "loading..."
			return

		return if not showName.get() # nothing searched

		empty = shows.count().get() is 0
		Obs.observe !->
			if not selectedShow.get()
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
				Server.sync 'loadShow', show.peek('id'), !->
					Db.shared.set 'show', show.peek()
					Db.shared.set 'show', 'loading', true
			else
				selectedShow.set null

