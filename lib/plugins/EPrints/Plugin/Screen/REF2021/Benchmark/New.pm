package EPrints::Plugin::Screen::REF2021::Benchmark::New;

# "render" method shows a warning (to make sure the admins know what they're doing when pressing 'create')
# "action_create" method actually creates a new (empty benchmark)"

use EPrints::Plugin::Screen::REF2021;
@ISA = ( 'EPrints::Plugin::Screen::REF2021' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ create copy cancel /];

	my $actions_appear = [
		{
			place => "ref_benchmark_create",
			action => "create",
			position => 200,
		},
		{
			place => "ref_benchmark_create",
			action => "cancel",
			position => 100,
		},
		{
			place => "dataobj_tools",
			position => 100,
		},
	];

	# 'copy' only appears if there's something to Copy from (i.e. a Current Benchmark)
	if( defined $self->{session} 
		&& defined $self->{session}->get_database
		&& defined $self->{session}->{datasets}->{ref2021_benchmark}
		&& defined EPrints::DataObj::REF2021Benchmark->default( $self->{session} ) )
	{
		push @$actions_appear,	{
				place => "ref_benchmark_create",
				action => "copy",
				position => 200,
			};

	}

	$self->{appears} = $actions_appear;

	return $self;
}

sub can_be_viewed 
{ 
	my( $self ) = @_;

        my $ds = $self->{processor}->{dataset}; # set by Screen::Listing

	return $self->allow( 'ref2021_benchmark/create_new' ) if( defined $ds && ($ds->base_id eq 'ref2021_benchmark' || $ds->base_id eq 'ref2021_selection' ));
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

sub allow_copy
{
	my ( $self ) = @_;

	return $self->can_be_viewed();
}

sub allow_create
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

sub action_copy
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = 'REF2021::Benchmark::Copy';

	return;
}

sub action_create
{
	my( $self ) = @_;

	my $ds = $self->{processor}->{dataset};

	my $epdata = {};

	if( defined $ds->field( "userid" ) )
	{
		my $user = $self->{session}->current_user;
		$epdata->{userid} = $user->id;
	}

	$self->{processor}->{dataobj} = $ds->create_dataobj( $epdata );

	if( !defined $self->{processor}->{dataobj} )
	{
		my $db_error = $self->{session}->get_database->error;
		$self->{processor}->{session}->get_repository->log( "Database Error: $db_error" );
		$self->{processor}->add_message( 
			"error",
			$self->html_phrase( "db_error" ) );
		return;
	}

	$self->{processor}->{screenid} = "Workflow::Edit";
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $chunk = $session->make_doc_fragment;

	$chunk->appendChild( $self->html_phrase( 'create_warning') );

	$chunk->appendChild( $self->render_action_list_bar( "ref_benchmark_create" ) );

	return $chunk;
}


1;
