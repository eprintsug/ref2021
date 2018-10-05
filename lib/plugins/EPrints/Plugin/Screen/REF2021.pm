package EPrints::Plugin::Screen::REF2021;

# Abstract Class, exports some useful methods for rendering roles etc

use EPrints::Plugin::Screen;
@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	push @{$self->{actions}}, qw/ change_role reset_role change_benchmark reset_benchmark /;

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0 unless( $self->{session}->config( 'ref2021_enabled' ) && defined $self->{session}->current_user );

	# can't select if we don't have a current benchmark in place
	return 0 if !defined $self->current_benchmark;

        # sf2 - allow local over-ride of whether a user can view the listing page
        if( $self->{session}->can_call( 'ref2021_can_user_view_listing' ) )
        {
                my $rc = $self->{session}->call( 'ref2021_can_user_view_listing', $self->{session} ) || 0;
                return $rc;
        }

	return 0 unless( $self->{session}->current_user->exists_and_set( 'ref2021_uoa' ) || $self->{session}->current_user->exists_and_set( 'ref2021_uoa_role' ) );

	return $self->allow( "items" );
}

sub can_select
{
	my( $self ) = @_;

	# sf2 - allow local over-ride of whether a user can select
	if( $self->{session}->can_call( 'ref_can_user_select' ) )
	{
		my $rc = $self->{session}->call( 'ref_can_user_select', $self->{session}, $self->{processor}->{role} ) || 0;
		return $rc;
	}
	# conditions:
	#   * ref/select role
	#   * there is a current benchmark in place
	#   * user isn't selecting against the non-current BM
	#   * user has a UoA attached to their user account

	return 0 if
		!defined $self->{session}->current_user ||
		!$self->{session}->current_user->has_role( "ref/select" ) ||
		!defined $self->current_benchmark ||
		$self->current_benchmark->value( "default" ) ne "TRUE" ||
		!($self->{processor}->{role}->exists_and_set( 'ref2021_uoa' ) );	#|| $self->{processor}->{role}->exists_and_set( 'ref2021_uoa_role' ) );

	return 1;
}

# render warning/error if the user isn't allowed to select (to give clues)
# sf2 - would be good to tie this with "sub can_select" above
sub render_warnings
{
	my( $self ) = @_;

	if( !$self->{session}->current_user->has_role( "ref/select" ) )
	{
		return $self->{session}->render_message( 'warning', $self->html_phrase( 'user_cannot_select:no_role' ) );
	}

	if( !defined $self->current_benchmark )
	{
		return $self->{session}->render_message( 'warning', $self->html_phrase( 'user_cannot_select:no_current_benchmark' ) );
	}

	if( $self->current_benchmark->value( "default" ) ne "TRUE" )
	{
		return $self->{session}->render_message( 'warning', $self->html_phrase( 'user_cannot_select:benchmark_closed' ) );
	}

	if( !$self->{processor}->{role}->exists_and_set( 'ref2021_uoa' ) )
	{
		return $self->{session}->render_message( 'warning', $self->html_phrase( 'user_cannot_select:no_uoa' ) );
	}

	return $self->{session}->make_doc_fragment;	
}


sub allow_change_role { shift->can_be_viewed }
sub allow_reset_role { shift->can_be_viewed }
sub allow_change_benchmark { shift->can_be_viewed }
sub allow_reset_benchmark { shift->can_be_viewed }

sub properties_from
{
	my( $self ) = @_;

	my $session = $self->{session};

	$self->SUPER::properties_from;

	my $sconf = $session->config( "search", "ref" );
	$sconf->{"allow_blank"} = 1;	# to allow the search by userid

	$self->{processor}->{sconf} = $sconf;
	$self->{processor}->{benchmark} = $self->current_benchmark;
	$self->{processor}->{role} = $self->current_role;
}

sub from
{
	my( $self ) = @_;

	$self->{processor}->{role} = $self->current_role;

	$self->SUPER::from();
}

sub current_benchmark
{
	my( $self ) = @_;

	return undef unless( $self->{session}->config( 'ref2021_enabled' ) );

	# caches the benchmark object in the processor!
	return $self->{processor}->{benchmark}
		if exists $self->{processor}->{benchmark};

	my $benchmark;

	my $id = EPrints::Apache::AnApache::cookie(
		$self->{session}->{request},
		"eprints_ref_benchmark"
	);
	if( $id )
	{
		$benchmark = $self->{session}->dataset( "ref2021_benchmark" )->dataobj( $id );
	}
	$benchmark = EPrints::DataObj::REF2021Benchmark->default( $self->{session} )
		if !defined $benchmark;

	$self->{processor}->{benchmark} = $benchmark;

	return $benchmark;
}

sub user_roles
{
	my( $self, $user ) = @_;

	if( !defined $self->{processor}->{roles} )
	{
		my $list = $self->{session}->call( "ref2021_roles_for_user",
				$self->{session},
				$user
			);
		$list = $list->reorder( "name" );
		$self->{processor}->{roles} = $list;
	}

	return $self->{processor}->{roles};
}

sub current_role
{
	my( $self ) = @_;

	return undef unless( $self->{session}->config( 'ref2021_enabled' ) );

	# try the 'role' parameter or 'eprints_ref_roleid cookie'
	if( !defined $self->{processor}->{role} )
	{
		my %valid = map { $_ => 1 } @{$self->user_roles( $self->{processor}->{user} )->ids};

		foreach my $roleid (
			scalar($self->{session}->param( "role" )),
			EPrints::Apache::AnApache::cookie(
					$self->{session}->{request},
					"eprints_ref_roleid"
				)
		  )
		{
			next if !$valid{$roleid};
			$self->{processor}->{role} = $self->{session}->user( $roleid );
			last if defined $self->{processor}->{role};
		}
	}

	# still not defined, so lets default to the current user
	if( !defined $self->{processor}->{role} )
	{
		$self->{processor}->{role} = $self->{processor}->{user};
	}

	return $self->{processor}->{role};
}

sub _action_redirect
{
	my( $self ) = @_;

	# behave like a POST with redirect_to_me_url
	my $uri = URI->new( $self->{session}->current_url( host => 1 ) );
	$uri->query( scalar $self->{session}->param( "params" ) );
	if( !$uri->query )
	{
		$uri->query_form( screen => $self->{processor}->{screenid} );
	}
	$self->{processor}->{redirect} = $uri;
}

sub action_change_role
{
	my( $self ) = @_;

	my $roleid = $self->{session}->param( "role" );
	my $role = $self->{session}->user( $roleid );

	if( !defined $role || $role->id == $self->{session}->current_user->id )
	{
		return $self->action_reset_role;
	}

	$self->set_cookie( "eprints_ref_roleid", $role->id );

	$self->_action_redirect;
}

sub action_reset_role
{
	my( $self ) = @_;

	$self->set_cookie( "eprints_ref_roleid", "", 1 );

	$self->_action_redirect;
}

sub action_change_benchmark
{
	my( $self ) = @_;

	$self->_action_redirect;

	my $benchmarkid = $self->{session}->param( "benchmark" );
	my $benchmark = $self->{session}->dataset( "ref2021_benchmark" )->dataobj( $benchmarkid );
	return if !defined $benchmark;

	$self->set_cookie( "eprints_ref_benchmark", $benchmark->id );
}

sub action_reset_benchmark
{
	my( $self ) = @_;

	$self->_action_redirect;

	$self->set_cookie( "eprints_ref_benchmark", "", 1 );
}

sub set_cookie
{
	my( $self, $name, $value, $expires ) = @_;

	my $cookie = $self->{session}->{query}->cookie(
			-name    => $name,
			-path    => "/",
			-value   => $value,
			-expires => $expires,
			-domain  => $self->{session}->config("cookie_domain"),
		);

	$self->{session}->{request}->err_headers_out->{"Set-Cookie"} = $cookie;
}

sub render
{
	my( $self ) = @_;

	return $self->{session}->make_text( "You shouldn't call this page directly." );
}

sub render_benchmarks
{
	my( $self, $phraseid ) = @_;

	$phraseid ||= "ref2021:benchmarks";

	my $session = $self->{session};
	my $processor = $self->{processor};

	my $benchmark = $processor->{benchmark};
	my $frag = $session->make_doc_fragment;

	my $benchmarks = [];
	my %labels;

	my $current_bm = EPrints::DataObj::REF2021Benchmark->default( $session );
	my $current_bmid = (defined $current_bm) ? $current_bm->get_id : -1;

	$session->dataset( "ref2021_benchmark" )->search->map(sub {
		(undef, undef, my $benchmark, my $info) = @_;

		push @$benchmarks, $benchmark->id;
		$labels{$benchmark->id} = $session->xhtml->to_text_dump(
			$benchmark->render_citation
		);

		# show which one is the current benchmark in the selection list
		$labels{$benchmark->id} .= " (*)" if( $benchmark->id == $info->{current_bmid} );
	}, { current_bmid => $current_bmid } );

	my $form = $self->render_form;
	$form->setAttribute( 'id', 'benchmarks' );
	$form->appendChild( $session->render_hidden_field( "params", $session->get_request->args ) );

	my $buttons = $form->appendChild( $session->make_element( "span",
		class => "ep_no_js",
	) );
	$buttons->appendChild( $session->render_action_buttons(
		change_benchmark => $session->phrase( "ref2021:change_benchmark" ),
		reset_benchmark => $session->phrase( "ref2021:reset_benchmark" ),
	) );

	my $select = $form->appendChild( $session->render_option_list(
		name => 'benchmark',
		values => $benchmarks,
		labels => \%labels,
		default => $benchmark->id,
	) );
	$select->setAttribute( "onchange" => <<'EOJ' );
$($('benchmarks')['_action_change_benchmark']).click();
EOJ

	$frag = $session->html_phrase( $phraseid,
		change_benchmark => $form,
		current_benchmark => $benchmark->render_citation,
	);

	return $frag;
}

sub render_roles
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $processor = $self->{processor};

	my $frag = $session->make_doc_fragment;

	my $user = $processor->{user};
	my $role = $processor->{role};

	if( !$self->user_roles( $user )->count )
	{
		return $session->html_phrase( 'ref2021:error:no_users' );
	}

	# construct labels

	my $form = $self->render_form;
	$form->setAttribute( 'id', 'roles' );
	$form->appendChild( $session->render_hidden_field( "params", $session->get_request->args ) );

	my $buttons = $form->appendChild( $session->make_element( "span",
		class => "ep_no_js",
	) );
	$buttons->appendChild( $session->render_action_buttons(
		change_role => $session->phrase( "ref2021:change_role" ),
		reset_role => $session->phrase( "ref2021:reset_role" ),
	) );

	my $div = $session->make_element( 'div',
		style => 'text-align:center;margin:auto;',
		id => 'ep_roles_container',
	);
	$div->appendChild( $session->make_element( 'img',
		src => $session->current_url( path => 'static', "style/images/loading.gif" )
	) );
	$form->appendChild( $div );

	$frag = $session->html_phrase( "ref2021:roles",
		change_role => $form,
		current_user => $role->render_description,
	);

	my $url = URI->new( $session->current_url );
	my $parameters = $session->{request}->args;
	$parameters .= "&ajax=1&part=roles";
	$frag->appendChild( $self->make_javascript( <<"EOJ" ) );
Event.observe(window, 'load', function() {
	new Ajax.Updater( 'ep_roles_container', '$url', {
		method: 'get',
		evalScripts: true,
		parameters: '$parameters'
	});
});
EOJ

	return $frag;
}

sub ajax_roles
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $processor = $self->{processor};

	my $frag = $session->make_doc_fragment;

	my $user = $processor->{user};
	my $role = $processor->{role};

	my @roles;
	my %labels;

	$self->user_roles( $user )->map(sub {
		(undef, undef, my $_user) = @_;

		push @roles, $_user->id;
		$labels{$_user->id} = $_user->render_citation( 'brief' );
	});
	
	if( !exists $labels{$role->id} )
	{
		unshift @roles, $role->id;
		$labels{$role->id} = $role->render_citation( 'brief' );
	}

# don't show the current user if he/she isn't part of that uoa
#
#	if( !exists $labels{$user->id} )
#	{
#		unshift @roles, $user->id;
#		$labels{$user->id} = $user->render_citation( 'brief' );
#	}

	$_ = $session->xhtml->to_text_dump( $_ ) for values %labels;

	my $select = $frag->appendChild( $session->render_option_list(
		name => 'role',
		values => \@roles,
		labels => \%labels,
		height => 10,
		default => $role->id,
	) );
	my $index = 0;
	foreach my $userid (@roles)
	{
		last if $userid == $role->id;
		$index++;
	}

# the JS block below is scrolling the <select>, in case you were wondering.

	$frag->appendChild( $session->make_javascript( <<"EOJ" ) );
var select = \$('role');
if( $index + 1 == select.options.length )
	select.options[0].selected = true;
else if( $index + 10 >= select.options.length )
	select.options[select.options.length - 1].selected = true;
else
	select.options[$index + 10].selected = true;
select.options[$index].selected = true;
select.onchange = function() { 
	\$(\$('roles')['_action_change_role']).click();
};
EOJ

	return $frag;
}

sub render_tools
{
	my( $self ) = @_;

	my $frag = $self->{session}->make_doc_fragment;

	my $tools = $self->render_action_list_short( "ref2021_tools" );

	if( defined $tools && $tools->getElementsByTagName( 'input' ) )
	{
		$frag->appendChild( $self->{session}->html_phrase( 'ref2021:tools:header' ) );
		$frag->appendChild( $tools );
	}


	return $frag;
}

# copy EPrints::Plugin::Screen::render_action_list (but does not show the actions' descriptions)
sub render_action_list_short
{
        my( $self, $list_id, $hidden ) = @_;

        my $session = $self->{session};

        my $table = $session->make_element( "table", class=>"ep_act_list", width=>'100%' );
        foreach my $params ( $self->action_list( $list_id ) )
        {
                my $tr = $session->make_element( "tr" );
                $table->appendChild( $tr );

                my $td = $session->make_element( "td", class=>"ep_act_list_button", width=>'100%', align=>'center', style=>'text-align:center;' );
                $tr->appendChild( $td );
                $td->appendChild( $self->render_action_button( { %$params, hidden => $hidden } ) );
        }

        return $table;
}

sub render_selections
{
	my( $self ) = @_;

	my $repo = $self->{session};
	my $processor = $self->{processor};

	my $selections = EPrints::DataObj::REF2021Selection::search_by_user( $repo, $processor->{role} );

	unless( $selections->count )
        {
                return $repo->html_phrase( "ref2021/select:none_selected" );
        }

        my $table = $repo->make_element( "table", class=>"ref_current_selections" );
        my $action_url = $repo->get_full_url;

     	my $roleid = $processor->{role}->get_id;
	my $userid = $repo->current_user->get_id;

	my $params = "";
	foreach my $p ( $repo->param )
	{
		$params .= "&$p=".$repo->param( $p );
	}

	$params =~ s/'/&#39;/g;

        my $n = 1;
	foreach my $selection ($selections->get_records)
        {
        	#my $already_selected = 0;
		my $eprintid = $selection->get_value( 'eprint_id' );
        	my @names;
		my $others = $repo->make_doc_fragment;
		foreach my $otherid ( @{ EPrints::DataObj::REF2021Selection::who_selected( $repo, $eprintid ) || [] } )
		{
			if( $otherid == $roleid )
			{
			#	$already_selected = 1;
			#	push @names, "You";
				next;
			}
			my $other = $repo->dataset( 'user' )->dataobj( $otherid );
			if( defined $other )
			{
				push @names, EPrints::Utils::tree_to_utf8( $other->render_description );
			} 
			else 
			{
				push @names, $repo->phrase( "ref2021:unknown_user", id => $otherid );
			}
		}
		if( scalar( @names ) > 0 )
		{
			$others->appendChild( $repo->html_phrase( 'ref2021/select:also_selected_by',
				names => $repo->make_text( join(", ", @names) ) ) );
		}

		my $actions = $repo->make_doc_fragment;

		my $remove = $repo->make_element( "a", href => "#",
				onclick => "return EPJS_REF2021_RemoveSelection( '$roleid', '$eprintid', '$userid', '$params' );"
		);
		my $uri = URI->new( $repo->current_url( host => 1 ) );
		$uri->query_form(
			screen => "REF2021::Status",
			role => $roleid,
			user => $userid,
			eprint => $eprintid,
		);
		$remove = $repo->make_element( "a",
			href => sprintf("javascript:EPJS_REF2021_Update('%s', '%s')",
				substr("$uri",0,-1-length($uri->query)),
				$uri->query,
			),
		);

		$remove->appendChild( $repo->html_phrase( "ref2021/select:remove_button" ) );

		my $qualify = $repo->render_link( $selection->get_control_url );
		$qualify->appendChild( $repo->html_phrase( "ref2021/select:qualify_button" ) );

		$actions->appendChild( $qualify );
		$actions->appendChild( $repo->make_element( "br" ) );
		$actions->appendChild( $remove );

        	$table->appendChild( $selection->render_citation( 'action', n => [ $n++, 'INTEGER' ],
									    actions => [ $actions, 'XHTML' ],
									    others => [ $others, 'XHTML' ],
		) );
	}

        return $table;
}

# 3.2's citations bork make_javascript
sub make_javascript
{
	my( $self, $source ) = @_;

	my $script = $self->{session}->make_element( "script",
		type => "text/javascript",
	);
	$script->appendChild( $self->{session}->make_text( "// " ) );
	$script->appendChild( $self->{session}->make_element( "br" ) );
	$script->appendChild( $self->{session}->xml->create_cdata_section(
		"\n$source\n// "
		) );

	return $script;
}

# this is in Screen in 3.3+
sub hidden_bits
{
	my( $self ) = @_;

	return screen => $self->{processor}->{screenid};
}

sub render_hidden_bits
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $chunk = $session->make_doc_fragment;
	my @params = $self->hidden_bits;
	while(@params)
	{
		$chunk->appendChild( $session->render_hidden_field( splice(@params,0,2) ) );
	}

	return $chunk;
}

sub export
{
        my( $self ) = @_;

        my $repo = $self->{session};
        my $frag = $repo->make_doc_fragment;

        my $part = $repo->param( "part" );
        $part = "" if !defined $part;
        my $f = "ajax_$part";

        if( $self->can( $f ) )
        {
                $frag->appendChild( $self->$f() );
        }

        binmode(STDOUT, ":utf8" );
        print $repo->xhtml->to_xhtml( $frag );
}

1;
