package EPrints::Plugin::Screen::REF2021::REF4::Listing;

use EPrints::Plugin::Screen::REF2021;
@ISA = ( 'EPrints::Plugin::Screen::REF2021' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

        $self->{appears} = [
                {
                        place => "ref2021_tools",
                        position => 250,
                }
        ];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;
	
	my $user = $self->{session}->current_user;

	# who can view the reports?
	# main REF2021 Admins? role = ?
	# people who have their ref2021_uoa_role field set

	# return 1 if( defined $user && $user->has_role( 'ref/admin' ) );
	
	return 0 if !defined $self->current_benchmark;

        # sf2 - allow local over-ride of whether a user can view the REF1 Data page
        if( $self->{session}->can_call( 'ref_can_user_view_ref4' ) )
        {
                my $rc = $self->{session}->call( 'ref_can_user_view_ref4', $self->{session} ) || 0;
                return $rc;
        }

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
	my $benchmark_id = $benchmark->get_id;

	my $chunk = $session->make_doc_fragment;

	my $user = $session->current_user;

	my $ref_roles = $user->get_value( 'ref2021_uoa_role' );

	return $chunk unless( EPrints::Utils::is_set( $ref_roles ) );

	# render current benchmark
	$chunk->appendChild( $self->render_benchmarks );

        my $container = $session->make_element( 'div', align => 'center', style => 'width:100%;text-align:center' );
        $chunk->appendChild( $container );
	# link to the available reports
	foreach my $uoa (sort @$ref_roles )
	{
		my $subject = $session->dataset( 'subject' )->dataobj( $uoa );
		next if !defined $subject;

#		my $href = URI->new( $session->config( "userhome" ) );
#		$href->query_form(
#			screen => "REF2021::Report::REF4::View",
#			uoa => $subject->id,
#		);
#		my $link = $session->render_link( $href );

		my $div = $session->make_element( "div", style=> 'margin-left:auto;margin-right:auto;font-weight:bold');
#		$link->appendChild( $subject->render_description );
#		$div->appendChild( $link );
		$div->appendChild( $subject->render_description );
	        $container->appendChild( $div );

		$container->appendChild( $self->render_result_row( $subject, $uoa, $benchmark_id ) );
	}

	return $chunk;
}

sub render_result_row
{
	my( $self, $subject, $uoa, $benchmark_id ) = @_;

	my $session = $self->{session};
	my $benchmark = $self->{processor}->{benchmark};
	my $env_ds = $session->dataset("ref2021_environment");
	my $searchexp = new EPrints::Search(
                session=>$session,
                satisfy_all => 1,
		custom_order => "year",
                dataset=>$env_ds );

        $searchexp->add_field(
                $env_ds->get_field( "ref_benchmarkid" ),
                $benchmark_id );
 
        $searchexp->add_field(
                $env_ds->get_field( "ref2021_uoa" ),
                $uoa );
       
        my $table = $session->make_element( 'table', class => 'ep_ref_listing_ref4' );
	my $th1 = $table->appendChild( $session->make_element( "th" ) );
	my $th2 = $table->appendChild( $session->make_element( "th" ) );
	my $th3 = $table->appendChild( $session->make_element( "th" ) );
	my $th4 = $table->appendChild( $session->make_element( "th" ) );
	my $th5 = $table->appendChild( $session->make_element( "th" ) );
	$th1->appendChild( $self->html_phrase("year") );
	$th2->appendChild( $self->html_phrase("degrees") );
	$th3->appendChild( $self->html_phrase("income") );
	$th4->appendChild( $self->html_phrase("income_in_kind") );
	$th5->appendChild( $self->html_phrase("actions") );
        
	my $list = $searchexp->perform_search;

	my $data = {};
	foreach my $year (qw( 2008 2009 2010 2011 2012 ))
	{
		$data->{$year}->{"id"} = -1;
		$data->{$year}->{"degrees"} = 0;
		$data->{$year}->{"income"} = 0;
		$data->{$year}->{"income_in_kind"} = 0;
	}

	$list->map(sub { 
		my ( $session, $dataset, $item ) = @_;
		my $year = $item->get_value("year");
		$data->{$year}->{"id"} = $item->get_id;
		$data->{$year}->{"degrees"} = $item->get_value("degrees"); 

		my $incomes = $item->get_value("income");
		foreach my $source (@$incomes)
		{
			$data->{$year}->{"income"} += $source->{"value"};
		}

		my $in_kind_incomes = $item->get_value("income_in_kind");
		foreach my $source (@$in_kind_incomes)
		{
			$data->{$year}->{"income_in_kind"} += $source->{"value"};
		}


	});
	# create any ref_environment entries that are required.
	
	foreach my $year (sort keys %$data)
	{
		if ($data->{$year}->{"id"} < 0)
		{
			my $new_item = $env_ds->create_dataobj();
			$new_item->set_value("ref_benchmarkid", [ $benchmark_id ] );
			$new_item->set_value("ref2021_uoa", [ $uoa ] );
			$new_item->set_value("year", $year);
			$new_item->set_value("degrees", 0);
			$new_item->commit;
		 	$data->{$year}->{"id"} = $new_item->get_id;
		}

	}
	foreach my $year (sort keys %$data)
	{
		my $tr = $table->appendChild( $session->make_element( "tr" ) );
		my $td1 = $tr->appendChild( $session->make_element( "td" ) );
		$td1->appendChild( $session->html_phrase("ref2021_environment_fieldopt_year_".$year) );
		my $td2 = $tr->appendChild( $session->make_element( "td" ) );
		$td2->appendChild( $session->make_text($data->{$year}->{'degrees'}) );
		my $td3 = $tr->appendChild( $session->make_element( "td" ) );
		$td3->appendChild( $session->make_text($data->{$year}->{'income'}) );
		my $td4 = $tr->appendChild( $session->make_element( "td" ) );
		$td4->appendChild( $session->make_text($data->{$year}->{'income_in_kind'}) );

		if ($data->{$year}->{"id"} >= 0)
		{
			my $edit_href = URI->new( $session->config( "userhome" ) );
			$edit_href->query_form(
				screen => "REF2021::REF4::Edit",
				dataset => "ref2021_environment",
				dataobj => $data->{$year}->{"id"},
				return_to => "REF2021::REF4::Listing",
			);
			my $edit_link = $session->render_link( $edit_href );

			my $td = $tr->appendChild( $session->make_element( "td" ) );
			$edit_link->appendChild( $self->html_phrase("edit") );
			$td->appendChild( $edit_link );
		}
		else
		{
			my $edit_href = URI->new( $session->config( "userhome" ) );
			$edit_href->query_form(
				screen => "REF2021::REF4::Edit",
				dataset => "ref2021_environment",
				dataobj => 1,
				return_to => "REF2021::REF4::Listing",
			);
			my $edit_link = $session->render_link( $edit_href );

			my $td = $tr->appendChild( $session->make_element( "td" ) );
			$edit_link->appendChild( $self->html_phrase("add") );
			$td->appendChild( $edit_link );
		}
	}

	return $table;
}

1;

