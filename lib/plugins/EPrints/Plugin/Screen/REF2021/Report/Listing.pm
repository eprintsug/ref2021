package EPrints::Plugin::Screen::REF2021::Report::Listing;

# Listing Screen for reports (allows users to select the UoAs, the report...)

use EPrints::Plugin::Screen::REF2021::Report;
@ISA = ( 'EPrints::Plugin::Screen::REF2021::Report' );

use strict;

our @STATS = (
	total_users => sub {
		my( $s ) = @_;

		$_[1] = {} if !defined $_[1];

		$_[1]{$s->value( "user_id" )}++;

		return scalar keys %{$_[1]};
	},
	total => sub {
		my( $s ) = @_;

		$_[1]++;

		return $_[1];
	},
	mean_self_rating => sub {
		my( $s ) = @_;

		$_[1] = [] if !defined $_[1];

		$_[1][0] += $s->value( "self_rating" );
		$_[1][1] ++;

		return $_[1][0] / $_[1][1];
	},
);

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

        $self->{appears} = [
                {
                        place => "ref2021_tools",
                        position => 200,
                }
        ];

	push @{$self->{actions}}, qw( select_report );

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;
	
	my $user = $self->{session}->current_user;

	return 0 if !defined $self->current_benchmark;

	return 1 if( defined $user && $user->exists_and_set( 'ref2021_uoa_role' ) );

	return 0;
}


# can the user access ALL the reports (eg. Admin)? If so, show the UoA tree?
# can the user access a single report (UoA admin)? If so, show the report for that UoA
# otherwise show the personal report?
sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $benchmark = $self->{processor}->{benchmark};

	my $chunk = $session->make_doc_fragment;

	my $user = $session->current_user;

	my $ref_roles = $user->get_value( 'ref2021_uoa_role' );

	return $chunk unless( EPrints::Utils::is_set( $ref_roles ) );

	# render current benchmark
	$chunk->appendChild( $self->render_benchmarks );
	
	# main form
	my $form_container = $chunk->appendChild( $session->make_element( 'div', class => 'ep_ref_listing_form' ) );
	my $form = $form_container->appendChild( $session->make_element( 'form', id => 'report_form' ) );

	# list of reports
	$form->appendChild( $self->render_reports );

        my $container = $session->make_element( 'div', align => 'center', class => "ep_ref_report_listing", id => 'ep_ref_report_listing_container' );
        $form->appendChild( $container );

        my $table = $session->make_element( 'table' );
        $container->appendChild( $table );

	my $tr = $table->appendChild( $session->make_element( "tr" ) );
	my $th = $tr->appendChild( $session->make_element( "th" ) );

	# select all Uoas link
	my $links_div = $th->appendChild( $session->make_element( 'div', class => 'ep_ref_listing_top_links' ) );
	my $select_link = $links_div->appendChild( $session->make_element( 'a', href => '#', onclick => 'return EPJS_REF2021_SelectAllUoAs();' ) );
	$select_link->appendChild( $session->make_text( 'Select all' ) ); 
	$links_div->appendChild( $session->make_element( 'br' ) );
	my $unselect_link = $links_div->appendChild( $session->make_element( 'a', href => '#', onclick => 'return EPJS_REF2021_UnselectAllUoAs();' ) );
	$unselect_link->appendChild( $session->make_text( 'Unselect all' ) ); 

	$th = $tr->appendChild( $session->make_element( 'th' ) );
	$th->appendChild( $session->make_text( 'Units of Assessment' ) );

	foreach my $id (map { $STATS[$_] } grep { $_ % 2 == 0 } 0..$#STATS)
	{
		my $th = $tr->appendChild( $session->make_element( "th" ) );
		$th->appendChild( $session->html_phrase( "ref2021:stat_$id" ) );
	}

	# link to the available reports. custom sort function so that b7..b9 shows before b10
	foreach my $uoa ( sort {

		my( $cmpa, $cmpb ) = ( $a, $b );
		if( $a =~ /^ref2021_\w(\d+)b?/ )
		{
			$cmpa = $1;
		}
		if( $b =~ /^ref2021_\w(\d+)b?/ )
		{
			$cmpb = $1;
		}
			return $cmpa <=> $cmpb; 

		} @$ref_roles )
	{
		my $subject = $session->dataset( 'subject' )->dataobj( $uoa );
		next if !defined $subject;

		$table->appendChild( $self->render_result_row( $subject ) );
	}


	$form->appendChild( $session->make_element( 'div', id => 'ref_data' ) );
	$form->appendChild( $self->render_hidden_bits );

	$form->appendChild( $session->make_element( 'input', type => 'submit', class => 'ep_form_action_button', value => 'View Report',
			onclick => 'return EPJS_REF2021_SerialiseUoAs();' ) );

	return $chunk;
}

sub render_reports
{
	my( $self ) = @_;

        my $frag = $self->{session}->make_doc_fragment;

	my @reports = @{$self->{session}->config( 'ref2021', 'reports' ) || [] };
	
    my $select = $self->{session}->make_element( 'select', id => "report", name => "report" );
	my $n = 0;
	foreach my $reportid ( @reports )
	{
		my $plugin = $self->{session}->plugin( "Screen::REF2021::Report::$reportid" ) or next;

		my $option = $select->appendChild( $self->{session}->make_element( 'option', value => $reportid ) );
		$option->appendChild( $plugin->render_title );

		if( $n++ == 0 )
		{
			$option->setAttribute( 'selected', 'selected' );
		}
	}

	if( $n == 0 )
	{
		return $self->html_phrase( 'no_reports' )
	}

	$frag->appendChild( $self->{session}->make_text( 'Report: ' ) );
	$frag->appendChild( $select );
	return $frag;
}

sub render_result_row 
{ 
	my( $self, $subject ) = @_;

	my $session = $self->{session};
	my $benchmark = $self->{processor}->{benchmark};

	my @ctx = map { undef } @STATS;
	my %results;

	# build a list of users that belong to that UoA
	# get the list of publications belonging to that UoA
	# cross-ref!

	my $users = $session->dataset( 'user' )->search( filters => [
                { meta_fields => [ "ref2021_uoa" ], value => $subject->id, },
        ]);

	my %valid_userids;
	$users->map( sub {
		(undef, undef, my $user) = @_;
		$valid_userids{$user->get_id} = undef;
	});

	$benchmark->uoa_selections( $subject )->map(sub {
		(undef, undef, my $selection) = @_;

		# perform the compound AND
		my $ok = 0;
		for(@{$selection->value( "ref" )})
		{
			$ok = 1, last
				if $_->{benchmarkid} == $benchmark->id && $_->{uoa} eq $subject->id;
		}
		return if !$ok;

		return if( !exists $valid_userids{$selection->value( 'user_id' )} );

		foreach my $i (grep { $_ % 2 == 0 } 0..$#STATS)
		{
			my( $id, $f ) = @STATS[$i,$i+1];
			$results{$id} = &$f( $selection, $ctx[$i] );
		}
	});

	my $tr = $session->make_element( "tr" );
	# tick-box
	{
		my $td = $tr->appendChild( $session->make_element( 'td' ) );
		$td->appendChild( $session->make_element( 'input', type => 'checkbox', value => $subject->id ) );
	}
	# title
	{
		my $td = $tr->appendChild( $session->make_element( "td" ) );
		$td->appendChild( $subject->render_description );
	}
	foreach my $id (map { $STATS[$_] } grep { $_ % 2 == 0 } 0..$#STATS)
	{
		my $td = $tr->appendChild( $session->make_element( "td" ) );
		$results{$id} = sprintf( "%.3f", $results{$id} ) if( defined $results{$id} && $results{$id} =~ /^\d+\.\d+$/ );
		$td->appendChild( $session->make_text( $results{$id} || '0' ) );
	}

	return $tr;
}


1;

