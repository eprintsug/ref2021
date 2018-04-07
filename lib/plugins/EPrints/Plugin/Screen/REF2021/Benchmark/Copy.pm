package EPrints::Plugin::Screen::REF2021::Benchmark::Copy;

use EPrints::Plugin::Screen::REF2021;
@ISA = ( 'EPrints::Plugin::Screen::REF2021' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	return $self;
}

sub can_be_viewed 
{ 
	my( $self ) = @_;

        if( defined $self->{processor}->{dataset} )
        {
                return 0 if( $self->{processor}->{dataset}->id ne 'ref2021_benchmark' );
        }


	return $self->allow( 'ref2021_benchmark/create_new' );
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


sub action_copy
{
	my( $self ) = @_;

	my $progressid = $self->{session}->param( 'progressid' );
	unless( defined $progressid )
	{
		return $self->{session}->make_text( 'cancelled: cannot find the progressid...' );
	}

	my $progress = EPrints::DataObj::UploadProgress->new( $self->{session}, $progressid );
	unless( defined $progress )
	{
		return $self->{session}->make_text( 'cancelled: cannot find the progress...' );
	}

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

	# sf2 - Now we need to copy all the REF2021_Selection objects from the current benchmark to this new one

	my $bm = EPrints::DataObj::REF2021Benchmark->default( $self->{session} );

	# sf2 - of course if none exists, we just return... this will redirect to the REF2021 Benchmark workflow
	return unless( defined $bm );

	# sf2 - this would be weird...
	return if( $bm->get_id == $self->{processor}->{dataobj}->get_id );

	# need to find all the selections belonging to that BM
	my $list = $bm->selections();
	
	my $info = {
		bmid => $bm->get_id, 
		newbm => $self->{processor}->{dataobj}, 
		n => 0,
		progress => $progress
	};

	$list->map( sub {
		my( $session, $dataset, $object, $info ) = @_;

		my @ref = @{ $object->get_value( 'ref' ) || [] };

		my $uoa;
		foreach(@ref)
		{
			if( $_->{benchmarkid} == $info->{bmid} )
			{
				$uoa = $_->{uoa};
			}
		}

		$object->select_for( $info->{newbm}, $uoa );
		$object->{non_volatile_change} = 0;
		$object->commit;
		$info->{n}++;
		$info->{progress}->set_value( 'received', $info->{n} );
		$info->{progress}->commit;

	}, $info );

	my $chunk = $self->{session}->make_doc_fragment;

	$chunk->appendChild( $self->{session}->render_message( 'message', $self->{session}->make_text( 'Successfully copied '.$info->{n}.' items from the current benchmark' ) ) );

	my $url = $self->{session}->get_url."?screen=Workflow::Edit&dataset=ref2021_benchmark&dataobj=".$self->{processor}->{dataobj}->get_id;

	$chunk->appendChild( $self->{session}->make_element( 'input', type => 'submit',
				class => 'ep_form_action_button',
				value => 'Continue',
				onclick => "window.location = '$url';return false;"
	) );

	$chunk->appendChild( $self->{session}->make_javascript( "\$( 'progress' ).remove();" ) );

	return $chunk;
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $chunk = $session->make_doc_fragment;

	$chunk->appendChild( $self->html_phrase( 'page' ) );

	my $form = $session->render_form;
	$chunk->appendChild( $form );
	$form->setAttribute( 'id', 'copyform' );

	srand;
	my @a = ();
	for(1..16) { push @a, sprintf( "%02X",int rand 256 ); }
	my $progressid = join( "", @a );

	# need to find the size of the dataset...
	my $bm = EPrints::DataObj::REF2021Benchmark->default( $session );
	unless( defined $bm )
	{
		return $session->make_text( 'no current BM to copy from!!' );
	}

	my $ds_size = $bm->selections()->count;

	my $progress = EPrints::DataObj::UploadProgress->create_from_data( $session, {
		progressid => $progressid,
		size => $ds_size,
		received => 0,
	});

	unless( $progress )
	{
		EPrints->abort( 'Internal Error: failed to create new object.' );
	}

        my $upload_progress_url = EPrints::Utils::js_string( $session->get_url( path => "cgi" ) . "/users/ajax/ref_copy_progress?progressid=$progressid" );
	my $js_progressid = EPrints::Utils::js_string( $progressid );

	$form->appendChild( $session->make_javascript( <<JS ) );

function startEmbeddedBenchmarkCopy(form, options) {
    upload_progress_url = options.url;
    progress = {};
    progress.id = options.progressid;
        var bits = form.action.split("#", 2);
        form.action = bits[0];
    if (form.action.match(/\\?/))
        form.action += '&progress_id=' + progress.id;
    else
        form.action += '?progress_id=' + progress.id;
        if (bits.length == 2 )
                form.action += "#" + bits[1];
    progress.starttime  = new Date();
    progress.lasttime   = new Date(progress.starttime);
    progress.lastamount = 0;
    window.setTimeout( reportUploadProgress, 100 );
    return true;
}

startEmbeddedBenchmarkCopy( \$( 'copyform' ), {'url': $upload_progress_url, 'progressid':$js_progressid} );

JS

        my $progress_bar = $session->make_element( "div", id => "progress" );
        $chunk->appendChild( $progress_bar );

	my $div = $session->make_element( 'div', id => 'testcopy' );
	$chunk->appendChild( $div );
	
        my $url = URI->new( $session->current_url );
        my $parameters = $session->{request}->args;
        $parameters .= "&ajax=1&part=copy_bm&progressid=$progressid";
        $div->appendChild( $session->make_javascript( <<"EOJ" ) );
Event.observe(window, 'load', function() {
        new Ajax.Updater( 'testcopy', '$url', {
                method: 'get',
                parameters: '$parameters'
        });
});
EOJ

	return $chunk;
}

sub wishes_to_export { shift->{session}->param( "ajax" ) }

sub export_mimetype { "text/html; charset=utf-8" }

sub export
{
        my( $self ) = @_;

        my $repo = $self->{session};
        my $frag = $repo->make_doc_fragment;

        my $part = $repo->param( "part" );
        $part = "" if !defined $part;

        if( $part eq "copy_bm" )
        {
		$frag->appendChild( $self->action_copy() );
        }

        binmode(STDOUT, ":utf8" );
        print $repo->xhtml->to_xhtml( $frag );
}

1;
