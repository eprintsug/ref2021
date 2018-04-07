package EPrints::Plugin::Screen::REF2021::Report;

# Abstract class that handles the Report tools

use EPrints::Plugin::Screen::REF2021;
@ISA = ( 'EPrints::Plugin::Screen::REF2021' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	push @{$self->{actions}}, qw( export );

	return $self;
}

sub can_be_viewed
{
        my( $self ) = @_;

	return 0 unless( $self->{session}->config( 'ref2021_enabled' ) );

	my $uoas = $self->current_uoas;
	return 0 if( !EPrints::Utils::is_set( $uoas ) );
        
	my $user = $self->{processor}->{user};
        return 0 if !defined $user;

	my %uoa_ids = map { $_->id => undef } @{ $uoas || [] };
        foreach my $uoa_role ( @{$user->value( 'ref2021_uoa_role' )||[]} )
        {
		return 1 if( exists $uoa_ids{$uoa_role} );	# sf2 - always true? $uoas is built on the current user's UoA roles
        }
        
	return 0;
}

sub users
{
	my( $self ) = @_;

	my $benchmark = $self->{processor}->{benchmark};
	my $default_benchmark = EPrints::DataObj::REF2021Benchmark->default( $self->{session} );

	return $self->{session}->dataset( "user" )->list( [] ) unless( defined $benchmark && defined $default_benchmark );

	if( $benchmark->get_id == $default_benchmark->get_id )
	{
		# will return all the users affiliated to a UoA (well for the UoAs selected for that report)
		return $self->users_by_uoa();
	}

	# will return all the users that have made a selection in the benchmark we're looking at
	# regardless of whether they're affiliated to a UoA or not
	return $self->users_by_selection();
}

# returns the users belonging to the selected UoA's, regardless of whether they've made selections or not
sub users_by_uoa
{
        my( $self ) = @_;

        my @uoas = @{ $self->{processor}->{uoas} || [] };

        my @uoa_ids = map { $_->id } @uoas;

        my $users = $self->{session}->dataset( 'user' )->search( filters => [
                { meta_fields => [ "ref2021_uoa" ], value => join( " ", @uoa_ids ),},
        ]);

        return $users->reorder( "ref2021_uoa/name" );
}

sub users_by_selection
{
        my( $self ) = @_;

        my $benchmark = $self->{processor}->{benchmark};
	my @uoas = @{ $self->{processor}->{uoas} || [] };

        my %userids;

	foreach my $uoa (@uoas)
	{
	        $benchmark->uoa_selections( $uoa )->map(sub {
        	        (undef, undef, my $selection) = @_;
                
                	$userids{$selection->value( "user_id" )} = undef;
	        });
	}
        
        my $list = $self->{session}->dataset( "user" )->list( [keys %userids] );
        $list = $list->reorder( "ref2021_uoa/name" );
        
        return $list;
}

sub allow_export { shift->can_be_viewed }
sub action_export {}

sub wishes_to_export {
	$_[0]->{session}->param( 'export' ) ||
	$_[0]->{session}->param( 'ajax' );
}

sub export_mimetype
{
	my( $self ) = @_;

	my $plugin = $self->{processor}->{plugin};
	return "text/html; charset=utf-8" if !defined $plugin;

	return $plugin->param( "mimetype" );
}

sub export
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $benchmark = $self->{processor}->{benchmark};
	my $uoa = $self->{processor}->{uoa};

	my $part = $session->param( "ajax" );
	my $f = "ajax_$part";

	if( $self->can( $f ) )
	{
		binmode(STDOUT, ":utf8");
		return $self->$f;
	}

	$session->not_found;
}

sub current_uoas
{
        my( $self ) = @_;

	my $param = $self->{session}->param( 'uoas' );
	return [] unless( defined $param );

	# un-escaping if necessary
	$param =~ s/\%2B/\+/g;

	# selected UoA's
        my @uoa_ids = split /[\+ ]/, $param;

        my %allowed_uoas = map { $_ => undef } @{$self->{session}->current_user->get_value( 'ref2021_uoa_role' ) || [] };

        my @uoas;
        foreach my $uoa_id (@uoa_ids)
        {
                next unless( exists $allowed_uoas{$uoa_id} );

                my $uoa = $self->{session}->dataset( 'subject' )->dataobj( $uoa_id );
                next unless( defined $uoa );

                push @uoas, $uoa;
        }

        return \@uoas;
}


sub properties_from
{
	my( $self ) = @_;

	$self->SUPER::properties_from;

	# load the selected UoA's
	$self->{processor}->{uoas} = $self->current_uoas;

	# instantiate the chosen Export plugin to actually export the data
	my $report = $self->{processor}->{report};
	my $format = $self->{session}->param( "export" );
	if( $format && $report )
	{
		my $plugin = $self->{session}->plugin( "Export::$format", report => $report );
		if( defined $plugin && $plugin->can_accept( "report2021/$report" ) )
		{
			$self->{processor}->{plugin} = $plugin;
		}
	}
}


## rendering

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my @uoas = @{ $self->{processor}->{uoas} || [] };

	my $chunk = $session->make_doc_fragment;

	$chunk->appendChild( $session->html_phrase( "Plugin/Screen/REF2021/Report:header", 
		benchmark => $self->render_current_benchmark, 
		export => $self->render_export_bar 
	) );
	
	$chunk->appendChild( $self->render_progress_bar );

	my $table = $chunk->appendChild( $session->make_element( "table",
		style => "display: none;",
		class => "ep_ref_problems"
	) );

	my $users = $self->users;
	my $user_ids = $users->ids;

	my $json = "[".join(',',@$user_ids)."]";

        my $url = $session->current_url( host => 1 );
        my $parameters = URI->new;
        $parameters->query_form(
                $self->hidden_bits,
        );
        $parameters = $parameters->query;

	$chunk->appendChild( $session->make_javascript( <<"EOJ" ) );
document.observe("dom:loaded", function() {

	new REF_Report( {
		ids: $json,
		step: 5,
		prefix: 'user',
		url: '$url',
		parameters: '$parameters'
	} ).execute();

});
EOJ

	# looking at legacy data ? i.e. former benchmarks? This is slightly more complex to deal with
        my $benchmark = $self->{processor}->{benchmark};
        my $current_benchmark = EPrints::DataObj::REF2021Benchmark->default( $self->{session} );

	my $is_legacy_data = 0;

	if( defined $benchmark && defined $current_benchmark &&
		$benchmark->get_id != $current_benchmark->get_id )
	{
		$is_legacy_data = 1;
	}

	my $current_uoa = undef;
	$users->map( sub {

		my( $session, undef, $user ) = @_;

		my $user_uoa = $user->value( 'ref2021_uoa' );

		if( !defined $user_uoa && $is_legacy_data )
		{
			# ok slightly more complex, we need to find that user's UoA from the selections that were made
	                $benchmark->user_selections( $user )->map(sub {
	                        (undef, undef, my $selection) = @_;
				return if( defined $user_uoa );
				$user_uoa = $selection->uoa( $benchmark ) 
			} );
		}

		if( !defined $current_uoa || $current_uoa ne $user_uoa )
		{
			if( defined $current_uoa ) { $chunk->appendChild( $session->make_element( 'br' ) ) }
			my $h3 = $chunk->appendChild( $session->make_element( 'h3', class => 'ep_ref_uoa_header' ) );

			$h3->appendChild( $self->{session}->dataset( 'subject' )->dataobj( $user_uoa )->render_description );
			$current_uoa = $user_uoa;
		}

		$chunk->appendChild( $session->make_element( "div",
			id => "user_".$user->id,
			class => 'ep_ref_report_box',
			style => 'display:none'
		) );

	} );

	return $chunk;
}


sub render_progress_bar
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $img = $session->current_url( path => "static", "style/images/progress_bar_orange.png" );
	my $progress = $session->make_element( "div",
		id => "progress",
		style => "clear: both; width: 200px; height: 15px; background-image: url($img); background-repeat: no-repeat; background-position: -200px 0px; border: 1px solid #888; border-radius: 10px; text-align: center; line-height: 15px;"
	);
	$progress->appendChild( $session->make_text( "Loading report..." ) );

	return $progress;
}

sub render_current_benchmark
{
	my( $self ) = @_;

	my $benchmark = $self->{processor}->{benchmark};
	
	return $self->{session}->make_doc_fragment unless( defined $benchmark );

	return $benchmark->render_citation;
}

sub render_export_bar
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $chunk = $session->make_doc_fragment;

	my @plugins = $self->export_plugins;
	
	return $chunk unless( scalar( @plugins ) );

	my $form = $chunk->appendChild( $self->render_form );
	$form->setAttribute( method => "get" );
	my $select = $form->appendChild( $session->render_option_list(
		name => 'export',
		values => [map { $_->get_subtype } @plugins],
		labels => {map { $_->get_subtype => $_->get_name } @plugins},
	) );
	$form->appendChild( 
		$session->render_button(
			name => "_action_export",
			class => "ep_form_action_button",
			value => $session->phrase( 'cgi/users/edit_eprint:export' )
	) );
	
	return $chunk;
}

### utility methods


sub to_json
{
        my( $self, $object ) = @_;

        if( ref( $object ) eq 'HASH' )
        {
                my @stuff;
                while( my( $k, $v ) = each( %$object ) )
                {
                        next if( !EPrints::Utils::is_set( $v ) );       # or 'null' ?
                        push @stuff, EPrints::Utils::js_string( $k ).':'.$self->to_json( $v )
                }
                return '{' . join( ",", @stuff ) . '}';
        }
        elsif( ref( $object ) eq 'ARRAY' )
        {
                my @stuff;
                foreach( @$object )
                {
                        next if( !EPrints::Utils::is_set( $_ ) );
                        push @stuff, $self->to_json( $_ );
                }
                return '[' . join( ",", @stuff ) . ']';
        }

        return EPrints::Utils::js_string( $object );
}

sub export_plugins
{
        my( $self ) = @_;

        my @plugin_ids = $self->{session}->plugin_list(
                type => "Export",
                can_accept => "report2021/".$self->{processor}->{report},
                is_visible => "staff",
		is_advertised => 1,
        );

        my @plugins;
	foreach my $id ( @plugin_ids )
        {
                my $p = $self->{session}->plugin( "$id" ) or next;
                push @plugins, $p;
        }

        return @plugins;
}

sub hidden_bits
{
	my( $self ) = @_;

	my @bits = ();

	my $uoas = join( "+", map { $_->id } @{ $self->{processor}->{uoas} || [] } );
	if( EPrints::Utils::is_set( $uoas ) )
	{
		push @bits, 'uoas';
		push @bits, $uoas;
	}

	return(
		$self->SUPER::hidden_bits,
		@bits
	);
}


1;
