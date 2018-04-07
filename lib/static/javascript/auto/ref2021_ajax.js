
function EPJS_REF2021_AddSelection( roleid, epid, userid, params )
{
	new Ajax.Request( '/cgi/users/ref/add_selection', {
		parameters: "roleid="+roleid+"&epid="+epid+"&userid="+userid,
		method: "POST",
		onSuccess: function( trans ) {
			EPJS_REF2021_RefreshContent( '/cgi/users/ajax?_ajax_action_id=refresh_selected'+params, 'epjs_ref_selected_items' );
			EPJS_REF2021_RefreshContent( '/cgi/users/ajax?_ajax_action_id=refresh_search'+params, 'epjs_ref_search_fragment' );
		}
	});

	// onClick event:
	return false;
};

function EPJS_REF2021_RemoveSelection( roleid, epid, userid, params )
{
	new Ajax.Request( '/cgi/users/ref/remove_selection', {
		parameters: "roleid="+roleid+"&epid="+epid+"&userid="+userid,
		method: "POST",
		onSuccess: function( trans ) {
			EPJS_REF2021_RefreshContent( '/cgi/users/ajax?screen=REF2021::Select&_ajax_action_id=refresh_selected'+params, 'epjs_ref_selected_items' );
			EPJS_REF2021_RefreshContent( '/cgi/users/ajax?screen=REF2021::Select&_ajax_action_id=refresh_search'+params, 'epjs_ref_search_fragment' );
		}
	});

	// onClick event:
	return false;
};

function EPJS_REF2021_RefreshContent( ajax_url, elementid )
{
	var w = $(elementid).offsetWidth;
	var h = $(elementid).offsetHeight;

	$(elementid).update( "" );

	var container = new Element( 'div', { 'align': 'center', 'valign': 'middle' } );
	container.style.width = w + "px";
	container.style.height = h + "px";
	container.appendChild( new Element( 'img', { 'src': '/style/images/loading.gif', 'border': '0' } ) );
	var span = new Element( 'span' );
	span.style.marginLeft = '10px';
	span.style.fontSize = '14px';
	span.update( "Refreshing..." );
	container.appendChild( span );

	$(elementid).appendChild( container );
	
	new Ajax.Request( ajax_url,
	{
		method:"GET",
		onSuccess:function(trans) {
			$(elementid).style.width = "auto";
			$(elementid).style.height = "auto";
			$(elementid).update( trans.responseText );
		}
	});
};


// sf2 - used by REF2021::Report::{report_id}
function EPJS_REF2021_ShowAllIssues() { 
	$$( 'div.ep_ref_report_problems' ).each( function(name,index) { name.show(); } ); 
	$$( 'div.ep_ref_report_user_problems' ).each( function(name,index) { name.show(); } ); 
	return false;  
}
function EPJS_REF2021_HideAllIssues() { 
	$$( 'div.ep_ref_report_problems' ).each( function(name,index) { name.hide(); } ); 
	$$( 'div.ep_ref_report_user_problems' ).each( function(name,index) { name.hide(); } ); 
	return false; 
} 

// sf2 - used by REF2021::Report::Listing
function EPJS_REF2021_SelectAllUoAs() { 
	var inp = $( 'ep_ref_report_listing_container' ).getElementsByTagName( 'input' );
	if( inp != null )
		$A( inp ).each( function( el ) { el.checked = true; } );
	return false;
}
function EPJS_REF2021_UnselectAllUoAs() { 
	var inp = $( 'ep_ref_report_listing_container' ).getElementsByTagName( 'input' );
	if( inp != null )
		$A( inp ).each( function( el ) { el.checked = false; } );
	return false;
}

function EPJS_REF2021_SerialiseUoAs() {
	var inp = $( "ep_ref_report_listing_container" ).getElementsByTagName( "input" );
	var n = 0;
	if( inp != null )
	{
		var uoas = null;
        	$A( inp ).each( function(el) {
	                if(el.checked) {
				if( uoas == null )
					uoas = el.value;
				else
					uoas += "+" + el.value;
				n++;
			}
	        } );
        	  
		if( n == 0 )
		{
			alert( 'You must select at least one Unit of Assessment' );
			return false;
		}
              
		$( "ref_data" ).insert( new Element( "input", { "type":"hidden", "name":"uoas", "value": uoas } ), { position: "end" } );
	}

	// also select the right report now:

	var screen = $( 'report_form' ).down( '#screen' );
	var reports = $( 'report_form' ).down( '#report' );
	if( screen == null || reports == null )
	{
		alert( '[Internal error] Missing params' );
		return false;
	}

	var selected = reports.options[reports.selectedIndex];
	if( selected != null && selected.value != null )
	{
		var report = selected.value;
		screen.value = 'REF2021::Report::' + report;
	}
	else
	{
		alert( '[Internal error] Missing params (selected report)' );
		return false;
	}

	$( "report_form" ).submit();

	return false;
}

// Used by the REF2021::Report::{report_id} classes
var REF2021_Report = Class.create({
	has_problems: 0,
	count: 0,
	runs: 0,
	progress: null,
	ids: Array(),
	step: 5,
	prefix: '',
	onProblems: function() {},
	onFinish: function() {},
	url: "",
	parameters: "",

	initialize: function(opts) {

		if( opts.ids )
			this.ids = opts.ids;
		if( opts.step )
			this.step = opts.step;
		if( opts.prefix )
			this.prefix = opts.prefix;
		if( opts.onFinish )
			this.onFinish = opts.onFinish;
		if( opts.onProblems )
			this.onProblems = opts.onProblems;
		if( opts.url )
			this.url = opts.url;
		if( opts.parameters )
			this.parameters = opts.parameters;
	},

	execute: function() {
		for(var i = 0; i < this.ids.length; i+=this.step)
		{
			var args = '&ajax='+this.prefix;
			for(var j = 0; j < this.step && i+j < this.ids.length; j++)
				args += '&' + this.prefix + '=' + this.ids[i+j];
			new Ajax.Request( this.url, {
				method: 'get',
				parameters: this.parameters + args,
				onSuccess: (function(transport) {

					// reply is JSON
					// json.data = [ { userid: STRING, citation: STRING, problems: ARRAY } ]

					var json = transport.responseText.evalJSON();
					var data = json.data;

					if( data == null )
						data = new Array();

					for( var i=0; i<data.length; i++ )
					{
						this.count++;
						var entry = data[i];
						// entry.userid - entry.problems (ARRAY) - entry.citation (STRING)

						if( entry == null )
							continue;
						var userid = entry.userid;
						if( userid == null )
							continue;

						var citation = entry.citation;
						var problems = entry.problems;

						var target_el = $( this.prefix + '_' + userid );
						if( target_el != null && citation != null )
						{
							target_el.update( citation );
							target_el.show();
							target_el.insert( new Element( 'div', { 'class': 'ep_ref_report_user_problems', 'id': this.prefix + '_' + userid + '_problems', 'style': 'display:none' } ), { 'position':'before' } );
						}

						if( problems != null && problems.length > 0 )
						{
							for( var j = 0; j < problems.length; j++ )
							{
								// hash format: problem.type - problem.desc - problem.eprintid
								var problem = problems[j];

								if( problem.eprintid != null )
								{
									// add as an eprint-related issue?
									this.addIssuesToEPrint( userid, problem.eprintid, problem.desc );
								}
								else
								{
									// general issue for that user
									this.addIssuesToUser( userid, problem );
								}
							}
						}
					}
					
					if( this.count == this.ids.length )
					{
						$('progress').remove();
						if( this.has_problems )
							this.onProblems(this);
						this.onFinish(this);
					}
					else
					{
						var width = 200;
						$('progress').style.backgroundPosition = Math.round(-width + width * this.count / this.ids.length) + "px 0px";
					}

					if( this.runs == 0 && this.count == 0 )
					{
						var pNode = $('progress').parentNode;
						$('progress').remove();
						var span = new Element( 'span', { 'class': 'ep_ref_report_empty' } );
						span.update( 'Report empty' );
						pNode.insert( span );
					}
					this.runs++;

				}).bind(this)
			});
		}
		if( this.ids == null || this.ids.length == 0 )
		{
			var pNode = $('progress').parentNode;
			$('progress').hide();
			var span = new Element( 'span', { 'class': 'ep_ref_report_empty' } );
			span.update( 'Report empty' );
			pNode.insert( span );
		}
	},

	buildProblemsBox: function( el ) {

		var boxid = el.getAttribute( 'id' ) + '_problems';

		var box = new Element( 'div', { 'class': 'ep_ref_report_problems', 'id': boxid } );

		el.insert( box, { 'position': 'end' } );

		return box;
	},

	addIssuesToUser: function( userid, problem ) {

		var desc = problem.desc;

		if( problem.field != null )
		{
			var field_el = $( 'user_'+userid+'_'+problem.field );
			if( field_el != null )
			{
				var div = new Element( 'div', { 'class': 'ep_ref_report_user_problems' } );
				field_el.update( div );
				div.update( desc );
				return;
			}
		}

		var element_id = this.prefix + '_' + userid + '_problems';
		var target_el = $( element_id );
		if( target_el != null ) {
			target_el.insert( desc, { 'position': 'top' } );
			target_el.show();
		}
	},

	addIssuesToEPrint: function( userid, eprintid, desc ) {

		var element_id = 'ep_ref_eprint_' + userid + '_' + eprintid
		// test if the "problems" box already exists:
		var problems_el = $( element_id + '_problems' );
		if( problems_el != null )
		{
			problems_el.insert( desc, { position: 'end' } );
			return;
		}

		var target_el = $( element_id );

		if( target_el != null )
		{
			/*
			var issue_link = new Element( 'a', { 'href': '#', 'class': 'ep_ref_report_problems_link' } );
			issue_link.update( 'Issues with selection' );
			issue_link.observe( 'click', this.showEPrintIssues.bindAsEventListener(this, element_id + "_problems" ) );
			*/
			
			/*var issue_link = new Element( 'span', { 'class': 'ep_ref_report_problems_link' } );
			issue_link.update( 'Issues with selection' );
			target_el.insert( issue_link, { position: 'end' } );*/

			var problem_box = new Element( 'div', { 'class': 'ep_ref_report_problems', 'id': element_id + "_problems" } );
			target_el.insert( problem_box, { position: 'end' } );
			problem_box.update( desc );
//			target_el.insert( new Element( 'div', { 'style': 'clear:right' } ), { 'position': 'end' } );
		}
	},
	showEPrintIssues: function(event) {

	        if( event != null )
        	        Event.stop( event );

	        var data = $A(arguments);
		var element_id = data[1];
		$( element_id ).show();
	}

});

