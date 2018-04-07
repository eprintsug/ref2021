package EPrints::Plugin::Screen::REF2021::User::EditCirc;

use EPrints::Plugin::Screen::Workflow::Edit;

@ISA = ( 'EPrints::Plugin::Screen::Workflow::Edit' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ stop save /];
=pod
	# EditCircLink provides the linking
	$self->{appears} = [
		{
			place => "dataobj_view_actions",
			position => 1650,
		},
		{
			place => "ref_listing_user_actions",
			position => 200
		},
	];
=cut
	$self->{staff} = 0;

	return $self;
}

sub can_be_viewed
{
        my( $self ) = @_;

        return 0 unless( $self->{session}->config( 'ref2021_enabled' ) );

        return 0 unless( defined $self->{processor}->{dataset} && ( $self->{processor}->{dataset}->id eq 'user' || $self->{processor}->{dataset}->id eq 'ref2021_circ' ) );

        # sf2 - allow local over-ride of whether a user can view the REF20211 Data page
        if( $self->{session}->can_call( 'ref_can_user_view_ref1' ) )
        {
                my $rc = $self->{session}->call( 'ref_can_user_view_ref1', $self->{session} ) || 0;
                return $rc;
        }
	    
        my $role = $self->get_user_from_circ();
	    return 0 unless( defined $role );

        my $role_uoa = $role->value( 'ref2021_uoa' );
        return 0 unless( defined $role_uoa );
        
	    my $user = $self->{session}->current_user;

        # current_user is a champion
        if( $user->exists_and_set( 'ref2021_uoa_role' ) )
        {
                # but is he a champion for the user's uoa?
                my $uoas = $user->value( 'ref2021_uoa_role' );
                foreach( @$uoas )
                {
                        return 1 if "$_" eq "$role_uoa";
                }

                return 0;
        }

        if( $role->get_id == $user->get_id )
        {
                return $user->has_role( 'ref/edit/ref1abc' );
        }

        return 0;
}

sub get_user_from_circ
{
	my( $self ) = @_;

	return undef unless( defined $self->{processor}->{dataobj} );

        if( $self->{processor}->{dataobj}->get_dataset_id eq 'ref2021_circ' )
        {
                my $user_id = $self->{processor}->{dataobj}->value( 'userid' );
                return 0 unless( defined $user_id );

		return $self->{session}->dataset( 'user' )->dataobj( $user_id );
        }

	return undef;
}

# forces the use of Screen::REF2021::allow (which should use Screen::allow) over Screen::Workflow::allow
sub allow
{
        my( $self, @args ) = @_;

        return $self->EPrints::Plugin::Screen::REF2021::allow( @args );
}

sub properties_from
{
        my( $self ) = @_;
        
	my $session = $self->{session};

	$self->{processor}->{return_to} = $session->param( 'return_to' );

	$self->{processor}->{role} = EPrints::Plugin::Screen::REF2021::current_role( $self );
	
	$self->SUPER::properties_from;
}

# sf2: copied from REF2021::user_roles (because used by REF2021::current_role, see a few lines above)
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


sub view_screen
{
	my( $self ) = @_;

	my $return_to = $self->{processor}->{return_to};

	if( EPrints::Utils::is_set( $return_to ) )
	{
		$return_to =~ s/^Screen:://g;
		return $return_to;
	}

	return "REF2021::User::EditCircLinkBack";
}

sub hidden_bits
{
        my( $self ) = @_;

        return(
                $self->SUPER::hidden_bits,
		return_to => $self->{processor}->{return_to}
        );
}

sub render_title
{
        my( $self ) = @_;

        my $chunk = $self->{session}->make_doc_fragment;

        $chunk->appendChild( $self->html_phrase( 'title' ) );

	my $user = $self->get_user_from_circ();
	if( defined $user )
        {
                $chunk->appendChild( $self->{session}->make_text( " - " ) );
                $chunk->appendChild( $user->render_value( 'name' ) );
        }

        return $chunk;
}

sub workflow
{
        my( $self, $staff ) = @_;

        my $cache_id = "workflow";
        $cache_id.= "_staff" if( $staff );

	my $workflow_id = 'default';
	my $cat = $self->{processor}->{role}->value( 'ref_category' );
	if( defined $cat && $cat eq 'C' )
	{
		$workflow_id = 'ref1c';
	}

        if( !defined $self->{processor}->{$cache_id} )
        {
                my %opts = (
                        item => $self->{processor}->{dataobj},
                        session => $self->{session} );
                $opts{STAFF_ONLY} = [$staff ? "TRUE" : "FALSE","BOOLEAN"];
                $self->{processor}->{$cache_id} = EPrints::Workflow->new(
                        $self->{session},
                        $workflow_id,
                        %opts );
        }

        return $self->{processor}->{$cache_id};
}

1;
