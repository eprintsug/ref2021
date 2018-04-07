package EPrints::Plugin::Screen::REF2021::Report::REF1b;

use EPrints::Plugin::Screen::REF2021::Report;
@ISA = ( 'EPrints::Plugin::Screen::REF2021::Report' );

use strict;

sub export
{
        my( $self ) = @_;

        my $benchmark = $self->{processor}->{benchmark};
        my $uoa = $self->{processor}->{uoa};

        my $plugin = $self->{processor}->{plugin};
        return $self->SUPER::export if !defined $plugin;

        $plugin->initialise_fh( \*STDOUT );
        $plugin->output_list(
                list => $self->users,
                fh => \*STDOUT,
        );
}

sub properties_from
{
	my( $self ) = @_;

        # will be used by the SUPER class:
	$self->{processor}->{report} = 'ref1b';

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
				$problem_data->{edit_url} = $problem->{eprint}->get_control_url;
			}

			if( defined $problem->{selection} && 0)
			{
				# are we really interested in Editing the Selection object =OR= the EPrint ??
				$problem_data->{edit_url} = $problem->{selection}->get_control_url;
			}
			push @json_problems, $problem_data;
		}

		push @{$json->{data}}, { userid => $userid, citation => EPrints::XML::to_string( $frag ), problems => \@json_problems };
	});

	print $self->to_json( $json );
}

sub render_user
{
        my( $self, $user, $problems ) = @_;

	my $session = $self->{session};
	my $chunk = $session->make_doc_fragment;

        my $link = $chunk->appendChild( $session->make_element( "a",
                name => $user->value( "username" ),
        ) );
        $chunk->appendChild( $user->render_citation( "ref" ) );

	# User metadata problems (and/or local checks!) - See part 3, section 1 of REF2021 Framework (esp. paragraph 84)
	my @user_problems = $self->validate_user( $user );

	# gather problems together (under one user)
	if( scalar( @user_problems )  && 0)
	{
		my $frag = $session->make_doc_fragment;
		
		my $c = 0;
		for( @user_problems )
		{
			$frag->appendChild( $session->make_element( 'br' ) ) if( $c++ > 0 );
			$frag->appendChild( $_ );
		}

		push @$problems, { user => $user, problem => $frag };
	}

	my $div = $chunk->appendChild( $session->make_element( "div" ) );
	$link = $div->appendChild( $session->make_element( "a",
		name => $user->value( "username" ),
	) );

	# cf Screen::REF2021::Overview
	my $circ = EPrints::DataObj::REF2021Circ->new_from_user( $session, $user->get_id, 1);
	$chunk->appendChild( $circ->render_citation( 'ref1b' ) );

	return $chunk;
}

sub render_problem_row
{
	my( $self, $problem ) = @_;

        my $session = $self->{session};
        my $benchmark = $self->{processor}->{benchmark};
        my $uoa = $self->{processor}->{uoa};

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

        $td = $tr->appendChild( $session->make_element( "td" ) );
      	$td->appendChild( $problem->{problem} );

        return $tr;
}

sub user_control_url
{
	my( $self, $user ) = @_;

	my $return_to = $self->get_id;
	$return_to =~ s/^Screen:://;

	my $href = URI->new( $self->{session}->config( "userhome" ) );
	$href->query_form(
		screen => "REF2021::User::Edit",
		dataobj => $user->id,
		return_to => $return_to
	);

	return $href;
}

sub validate_user
{
	my( $self, $user, $selection, $eprint ) = @_;

	my $f = $self->param( "validate_user" );
	return () if !defined $f;

	my @problems = &$f( @_[1..$#_], $self );

	return @problems;
}


1;
