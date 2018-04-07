package EPrints::Plugin::Screen::REF2021::Report::REF4;

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
	
	my %uoa_ids = map { $_->id => undef } @{ $self->{processor}->{uoas} || [] };

	my $list = $self->{session}->dataset( 'ref2021_environment' )->search(
		filters => [
			{ meta_fields => [ 'ref_benchmarkid' ], value => $benchmark->get_id },
			{ meta_fields => [ 'ref_uoa' ], value => join(" ", %uoa_ids ) },
		] );

	$plugin->initialise_fh( \*STDOUT );
	$plugin->output_list(
		list => $list,
		fh => \*STDOUT,
	);
}

# For REF20214, select the appropriate data from the dataset 
sub get_ref4_data
{
        my( $self ) = @_;
	
	my $session = $self->{session};
        my $benchmark = $self->{processor}->{benchmark};
	my %uoa_ids = map { $_->id => undef } @{ $self->{processor}->{uoas} || [] };

	my $data;

	foreach my $uoa ( %uoa_ids )
	{
		$session->dataset( 'ref2021_environment' )->search(
			filters => [
				{ meta_fields => [ 'ref_benchmarkid' ], value => $benchmark->get_id },
				{ meta_fields => [ 'ref_uoa' ], value => $uoa },
			]
		)->map( sub {

			my( undef, undef, $item ) = @_;

			my $year = $item->value( 'year' );
			$data->{$uoa}->{"degrees"}->{$year} = $item->value( 'degrees' );

			my $incomes = $item->value( 'income' );
			foreach my $source (@$incomes)
			{
				my $source_id = $source->{"source"};
				$data->{$uoa}->{"income"}->{$source_id}->{$year} = $source->{"value"};
			}

			my $income_in_kind = $item->value( 'income_in_kind' );
			foreach my $source (@$income_in_kind)
			{
				my $source_id = $source->{"source"};
				$data->{$uoa}->{"income_in_kind"}->{$source_id}->{$year} = $source->{"value"};
			}
		} );
	}
	
	return $data;
}


sub properties_from
{
	my( $self ) = @_;

	$self->{processor}->{report} = 'ref4';

	$self->SUPER::properties_from;

	# sf2
	return;

	$self->{processor}->{uoa} = $self->current_uoa;
	my $format = $self->{session}->param( "export" );
	if( $format )
	{
		my $plugin = $self->{session}->plugin( "Export::$format" );
		if( defined $plugin && $plugin->can_accept( "list/ref2021_environment" ) )
		{
			$self->{processor}->{plugin} = $plugin;
		}
	}
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my %uoa_ids = map { $_->id => undef } @{ $self->{processor}->{uoas} || [] };

	my $chunk = $session->make_doc_fragment;

	$chunk->appendChild( $session->html_phrase( "Plugin/Screen/REF2021/Report:header", 
		benchmark => $self->render_current_benchmark, 
		export => $self->render_export_bar 
	) );
	
	my $ref4_data = $self->get_ref4_data;
	my $n = 0;
	foreach my $uoa_id ( sort keys %{$ref4_data||{}} )
	{
                my $h3 = $chunk->appendChild( $session->make_element( 'h3', class => 'ep_ref_uoa_header' ) );
                $h3->appendChild( $self->{session}->dataset( 'subject' )->dataobj( $uoa_id )->render_description );
		$h3->setAttribute( 'style', 'margin-top:40px' ) if( $n++ );

		$chunk->appendChild( $self->render_ref4_data($ref4_data->{$uoa_id}) );
	}

	return $chunk;
}

sub render_ref4_data
{
	my( $self, $data ) = @_;

	my $session = $self->{session};
	my $benchmark = $self->{processor}->{benchmark};
	my $uoa = $self->{processor}->{uoa};

	my $chunk = $session->make_doc_fragment;

	my $hdiv = $chunk->appendChild( $session->make_element( "div", class=>"ep_ref_user_citation" ) );
	$hdiv->appendChild( $self->html_phrase("degrees_awarded") ); 
	my $div = $chunk->appendChild( $session->make_element( "div" ) );
       
        my $table = $session->make_element( 'table', class => 'ep_ref_report_ref4' );	#style=> 'margin-left:auto;margin-right:auto;' );
	$div->appendChild($table);
	my $th1 = $table->appendChild( $session->make_element( "th", style=>"text-align: left" ) );
	my $th2 = $table->appendChild( $session->make_element( "th", style=>"text-align: right" ) );
	$th1->appendChild( $self->html_phrase("year") );
	$th2->appendChild( $self->html_phrase("degrees") );

	foreach my $year (sort keys %{$data->{'degrees'}})
	{
 		my $tr = $table->appendChild( $session->make_element( "tr" ) );
		my $td1 = $tr->appendChild( $session->make_element( "td", style=>"text-align: left" ) );
		$td1->appendChild( $session->html_phrase("ref2021_environment_fieldopt_year_".$year) );
		my $td2 = $tr->appendChild( $session->make_element( "td", style=>"text-align: right" ) );
		$td2->appendChild( $session->make_text($data->{'degrees'}->{$year}) );
	}	

	foreach my $category (qw( income income_in_kind ))
	{
		my $idiv = $chunk->appendChild( $session->make_element( "div", class=>"ep_ref_user_citation" ) );
		$idiv->appendChild( $self->html_phrase("research_".$category) ); 
		my $div = $chunk->appendChild( $session->make_element( "div" ) );

		my $done_any = 0;	
		foreach my $source (sort keys %{$data->{$category}})
		{
			my $source_para = $div->appendChild( $session->make_element( "p" ) );
			$source_para->appendChild( $self->html_phrase("research_income_source", 
                                                                       funding_source=>$session->html_phrase("ref2021_environment_fieldopt_".$category."_source_".$source) ) ); 
      	 
	        	my $table = $session->make_element( 'table', class => 'ep_ref_report_ref4' );
			$div->appendChild($table);
			my $th1 = $table->appendChild( $session->make_element( "th" ) );
			my $th2 = $table->appendChild( $session->make_element( "th" ) );
			$th1->appendChild( $self->html_phrase("year") );
			$th2->appendChild( $self->html_phrase($category) );
			foreach my $year (sort keys %{$data->{$category}->{$source}} )
			{
 				my $tr = $table->appendChild( $session->make_element( "tr" ) );
				my $td1 = $tr->appendChild( $session->make_element( "td", style=>"text-align: left" ) );
				$td1->appendChild( $session->html_phrase("ref2021_environment_fieldopt_year_".$year) );
				my $td2 = $tr->appendChild( $session->make_element( "td", style=>"text-align: right" ) );
				$td2->appendChild( $session->make_text($data->{$category}->{$source}->{$year}) );
			}
			$done_any++;
		}

		$chunk->appendChild( $self->html_phrase( 'no_data' ) ) if( !$done_any );
	}

	return $chunk;
}

1;

