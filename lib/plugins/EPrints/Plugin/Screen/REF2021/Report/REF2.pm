package EPrints::Plugin::Screen::REF2021::Report::REF2;

use EPrints::Plugin::Screen::REF2021::Report;
@ISA = ( 'EPrints::Plugin::Screen::REF2021::Report' );

use strict;

sub export
{
	my( $self ) = @_;

	my $plugin = $self->{processor}->{plugin};
	return $self->SUPER::export if !defined $plugin;

	my @ids;

	my $benchmark = $self->{processor}->{benchmark};
	my @uoas = @{ $self->{processor}->{uoas} || [] };

	$self->users->map(sub {
		(undef, undef, my $user ) = @_;

		$benchmark->user_selections( $user )->map(sub {
			(undef, undef, my $selection) = @_;

			# return if $selection->uoa( $benchmark ) ne $uoa->id;
			my $keep = 0;
			foreach my $uoa (@uoas)
			{
				if( $selection->uoa( $benchmark ) eq $uoa->id )
				{
					$keep = 1;
					last;
				}
			}

			push @ids, $selection->id if( $keep );
		});
	});

	my $selections = $self->{session}->dataset( "ref2021_selection" )->list( \@ids );

	$plugin->initialise_fh( \*STDOUT );
	$plugin->output_list(
		list => $selections,
		fh => \*STDOUT,
	);
}

sub properties_from
{
	my( $self ) = @_;

	$self->{processor}->{report} = 'ref2';

	$self->SUPER::properties_from;
}

sub ajax_user
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $json = { data => [] };

	$session->dataset( "user" )
	->list( [$session->param( "user" )] )
	->map(sub {
		(undef, undef, my $user) = @_;

		return if !defined $user; # odd

		my @problems;

		my $userid = $user->get_id;

		my $frag = $self->render_user( $user, \@problems );

		my @json_problems;
		foreach my $problem (@problems)
		{
			next unless( EPrints::Utils::is_set( $problem ) );

			my $problem_data = {
				desc => EPrints::XML::to_string( $problem->{problem} ),
			};

			if( defined $problem->{eprint} )
			{
				$problem_data->{eprintid} = $problem->{eprint}->get_id;
			}

			push @json_problems, $problem_data;
		}

		push @{$json->{data}}, { userid => $userid, citation => EPrints::XML::to_string( $frag ), problems => \@json_problems };
	});

	print $self->to_json( $json );
}

# frag = $plugin->render_user( $user, $problems )
sub render_user
{
	my( $self, $user, $problems ) = @_;

	my $session = $self->{session};
	my $benchmark = $self->{processor}->{benchmark};
	my %uoa_ids = map { $_->id => undef } @{ $self->{processor}->{uoas} || [] };

	my $chunk = $session->make_doc_fragment;

	my $link = $chunk->appendChild( $session->make_element( "a",
		name => $user->value( "username" ),
	) );
	
	$chunk->appendChild( $user->render_citation( "ref2021" ) );

	my $selections = $benchmark->user_selections( $user );

	my $circ = EPrints::DataObj::REF2021Circ->new_from_user( $session, $user->get_id );
	my $expected_count = 4;
	if( defined $circ && $circ->is_set( 'complex_reduction' ) )
	{
		# complex_reduction = [0,1,2,3]
		$expected_count = 4 - $circ->get_value( 'complex_reduction' );
		$expected_count = 1 if( $expected_count < 1 );
	}

	if( $selections->count != $expected_count )
	{
		push @$problems, {
			user => $user,
			problem => $self->html_phrase( "error:bad_count",
				count => $session->make_text( $selections->count ),
			),
		};
	}

	my %uoas;

	my $select_n = 1;

	$selections->map(sub {
		(undef, undef, my $selection) = @_;

		my $eprint = $session->eprint( $selection->value( "eprint_id" ) );

		my $eprint_exists = 1;
			
		if( defined $eprint )
		{
			$chunk->appendChild( $selection->render_citation( "report",
					user => $user,
					eprint => $eprint,
					n => [$select_n, 'INTEGER' ]
				) );
		}
		else
		{
			push @$problems, {
				user => $user,
				problem => $session->html_phrase( 'ref2021:error:no_eprint' )
			};

			$chunk->appendChild( $session->html_phrase( 'ref2021:error:no_eprint' ) );

			return;
		}

		$select_n++;

		push @$problems,
			$self->validate_selection( $user, $selection, $eprint );

		my @others;

		$benchmark->eprint_selections( $eprint )->map(sub {
			(undef, undef, my $other) = @_;

			my $uoaid = $other->uoa( $benchmark );
			
			return if( !exists $uoa_ids{$uoaid} );

			return if $other->id == $selection->id;

			push @others, $other;
		});

		if( @others )
		{
			my $frag = $session->make_doc_fragment;
			foreach my $other (@others)
			{
				$frag->appendChild( $session->make_text( ", " ) )
					if $frag->hasChildNodes;
				$frag->appendChild( $session->make_text( $other->value( "user_title" ) ) );
			}

			my $p = $session->make_element( 'p' );
			$p->appendChild( $self->html_phrase( "error:duplicate", others => $frag ) );

			push @$problems, {
				user => $user,
				eprint => $eprint,
				selection => $selection,
				problem => $p
			};
		}

		$uoas{$selection->uoa( $benchmark )} = 1;
	});

	if( scalar keys %uoas > 1 )
	{
		my $problem = $session->make_doc_fragment;
		foreach my $uoaid (keys %uoas)
		{
			$problem->appendChild( $session->make_text( ", " ) )
				if $problem->hasChildNodes;
			my $uoa = $session->dataset( "subject" )->dataobj( $uoaid );
			$problem->appendChild(
				defined $uoa ?
					$uoa->render_description :
					$session->make_text( $uoaid )
			);
		}
		push @$problems, {
			user => $user,
			problem => $self->html_phrase( "error:cross_uoa",
				uoas => $problem,
			),
		};
	}

	return $chunk;
}

# frag = $plugin->render_problem_row( $problem )
sub render_problem_row
{
	my( $self, $problem ) = @_;

	my $session = $self->{session};
	# my $benchmark = $self->{processor}->{benchmark};

	my $tr = $session->make_element( "tr" );
	my $td;

	my $link_td = $tr->appendChild( $session->make_element( "td" ) );

	my $users = $problem->{user};
	$users = [$users] if ref($users) ne "ARRAY";
	$td = $tr->appendChild( $session->make_element( "td",
		style => "white-space: nowrap",
	) );
	foreach my $user (@$users)
	{
		$td->appendChild( $session->make_element( "br" ) )
			if $td->hasChildNodes;
		$td->appendChild( $user->render_citation_link( "brief" ) );

		$link_td->appendChild( $session->make_text( " " ) )
			if $link_td->hasChildNodes;
		my $link = $link_td->appendChild( $session->render_link(
			"#".$user->value( "username" ),
		) );
		$link->appendChild( $self->html_phrase( "view" ) );
		$link_td->appendChild( $session->make_text( "/" ) );
		$link = $link_td->appendChild( $session->render_link(
			$self->user_control_url( $user ),
		) );
		$link->appendChild( $self->html_phrase( "edit" ) );
	}

	my $eprint = $problem->{eprint};
	$td = $tr->appendChild( $session->make_element( "td" ) );
	if( defined $eprint )
	{
		$td->appendChild( $eprint->render_citation( "brief",
			url => $eprint->get_control_url,
		) );
	}

	$td = $tr->appendChild( $session->make_element( "td" ) );
	$td->appendChild( $problem->{problem} );

	return $tr;
}

sub user_control_url
{
	my( $self, $user ) = @_;

	my $href = URI->new( $self->{session}->config( "userhome" ) );
	$href->query_form(
		screen => "REF2021::Listing",
		role => $user->id,
		_action_change_role => 1,
	);

	return $href;
}

sub validate_selection
{
	my( $self, $user, $selection, $eprint ) = @_;

	my $f = $self->param( "validate_selection" );
	return () if !defined $f;

	my @problems = &$f( @_[1..$#_], $self );

	if( @problems == 0 )
	{
		return ();
	}
	else
	{
		my $frag = $self->{session}->make_doc_fragment;
		foreach my $problem (@problems)
		{
			my $p = $frag->appendChild( $self->{session}->make_element( 'p' ) );
			$p->appendChild( $problem );
		}
		return {
			user => $user,
			selection => $selection,
			eprint => $eprint,
			problem => $frag,
		};
	}
}

1;

