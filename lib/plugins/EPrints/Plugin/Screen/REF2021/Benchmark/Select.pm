package EPrints::Plugin::Screen::REF2021::Benchmark::Select;

use EPrints::Plugin::Screen::REF2021;
@ISA = ( 'EPrints::Plugin::Screen::REF2021' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ manage select_current cancel /];

	$self->{appears} = [
		{
			place => "dataobj_tools",
			position => 100,
		},
                {
                        place => "ref2021_tools",
                        position => 400,
			action => "manage",
                }

	];

	return $self;
}

sub can_be_viewed 
{ 
	my( $self ) = @_;

	my $ds = $self->{processor}->{dataset};	# set by Screen::Listing

	return $self->allow( 'ref2021_benchmark/select_current' ) if( defined $ds && ($ds->base_id eq 'ref2021_benchmark' || $ds->base_id eq 'ref2021_selection' ));
	return 0;
}

sub properties_from
{
	my( $self ) = @_;
	
	my $processor = $self->{processor};
	my $session = $self->{session};

	my $datasetid = "ref2021_benchmark";

	my $dataset = $session->dataset( $datasetid );
	if( !defined $dataset )
	{
		$processor->{screenid} = "Error";
		$processor->add_message( "error", $session->html_phrase(
			"lib/history:no_such_item",
			datasetid=>$session->make_text( $datasetid ),
			objectid=>$session->make_text( "" ) ) );
		return;
	}

	$processor->{"dataset"} = $dataset;

	$self->SUPER::properties_from;
}

sub allow_manage
{
	my( $self ) = @_;

	return $self->can_be_viewed();
}

sub action_manage
{
	my( $self ) = @_;
	
	$self->{processor}->{redirect} = $self->{session}->config( 'userhome' )."?screen=Listing&dataset=ref2021_benchmark";
}

sub allow_select_current
{
	my ( $self ) = @_;

	return $self->can_be_viewed();
}

sub allow_cancel
{
	my ( $self ) = @_;

	return $self->can_be_viewed();
}

sub action_cancel
{
	my( $self ) = @_;

	# redirect somewhere sensible
	$self->{processor}->{redirect} = $self->{session}->config( 'userhome' )."?screen=Listing&dataset=ref2021_benchmark";
}	

sub action_select_current
{
	my( $self ) = @_;

	$self->{processor}->{redirect} = $self->{session}->config( 'userhome' )."?screen=Listing&dataset=re2021f_benchmark";

	my $selected = $self->{session}->param( 'selected_benchmark' );
	return unless( defined $selected && $selected =~ /^\d+$/ );
	
	EPrints::DataObj::REF2021Benchmark::select_as_default( $self->{session}, $selected );

	return;
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $chunk = $session->make_doc_fragment;

	# search all REF2021 Benchmark objects
	# render 'em with radio-button

	# might restrict the search to benchmarks which are still valid 
	my $search = EPrints::Search->new(
		session => $session,
		dataset => $session->dataset( 'ref2021_benchmark' ),
		allow_blank => 1,
	);

	my $list = $search->perform_search();
	return $self->html_phrase( 'no_benchmark' ) unless( $list->count );

	my $selected_bm = $self->current_benchmark;
	my $selected_bm_id = defined $selected_bm ? $selected_bm->get_id : -1;

	# todo / help message

	my $form = $session->render_form();
	$chunk->appendChild( $form );

	my $table = $session->make_element( 'table', width => '70%', class => "ep_ref_benchmark_select" );
	$form->appendChild( $table );

	$list->map( sub {
		my( $session, $dataset, $object, $info ) = @_;
		my( $tr, $td );

		$tr = $session->make_element( 'tr' );
		$info->{table}->appendChild( $tr );

		$td = $tr->appendChild( $session->make_element( 'td', width => '10%' ) );
		my $input = $session->make_element( 'input', type => 'radio', name => 'selected_benchmark', value => $object->get_id() );

		$input->setAttribute( 'checked', 'checked' ) if( $object->get_id eq $info->{selected} );
		$td->appendChild( $input );
		
		$td = $tr->appendChild( $session->make_element( 'td', width => '90%' ) );
		$td->appendChild( $object->render_citation( ) );


	}, { table => $table, selected => "$selected_bm_id" } );	

	$form->appendChild( $self->render_hidden_bits() );	
	
	my $div = $session->make_element( 'div', style=>'width:100%;margin-left:auto;margin-right:auto;text-align:center;' );
	$form->appendChild( $div );
        $div->appendChild( $session->render_action_buttons(
                _order => [ "cancel", "select_current" ],
                cancel => $self->phrase( "action:cancel:title" ),
                select_current => $self->phrase( "action:select_current:title" ) )
        );

	return $chunk;
}


1;
