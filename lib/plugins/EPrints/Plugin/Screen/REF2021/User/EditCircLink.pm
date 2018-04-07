package EPrints::Plugin::Screen::REF2021::User::EditCircLink;

# a link between user dataobj -> ref_circ dataobj

use EPrints::Plugin::Screen::Workflow::Edit;

@ISA = ( 'EPrints::Plugin::Screen::Workflow::Edit' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ stop save /];

	$self->{appears} = [
		{
			place => "dataobj_view_actions",
			position => 1660,
		},
		{
			place => "ref2021_listing_user_actions",
			position => 200
		},
	];

	$self->{staff} = 0;

	return $self;
}

sub can_be_viewed
{
        my( $self ) = @_;

        return 0 unless( $self->{session}->config( 'ref2021_enabled' ) );

        return 0 unless( defined $self->{processor}->{dataset} && $self->{processor}->{dataset}->id eq 'user' );

        # sf2 - allow local over-ride of whether a user can view the REF20211 Data page
        if( $self->{session}->can_call( 'ref_can_user_view_ref1' ) )
        {
                my $rc = $self->{session}->call( 'ref_can_user_view_ref1', $self->{session} ) || 0;
                return $rc;
        }

	    # if called from a Workflow-type plugin, {dataobj} will be set to the "role"
	    # if called from a REF2021-type plugin (eg REF2021::Overview), {role} will be set to the "role"
	    my $role = $self->{processor}->{dataobj} || $self->{processor}->{role};
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

# forces the use of Screen::REF2021::allow (which should use Screen::allow) over Screen::Workflow::allow
sub allow
{
        my( $self, @args ) = @_;

        return $self->EPrints::Plugin::Screen::REF2021::allow( @args );
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

# properties_from() (called BEFORE from()) will set dataset to 'user' and dataobj to the user being viewed/edited
# from() allows us to redirect to the "real" EditCirc screen
sub from
{
	my( $self ) = @_;

	my $user = $self->{processor}->{dataobj};
	return unless( defined $user );

	my $circ = EPrints::DataObj::REF2021Circ->new_from_user( $self->{session}, $user->get_id, 1 );
	return unless( defined $circ );	# odd error
	
	my $redirect_url = $self->{session}->config( 'userhome' )."?screen=REF2021::User::EditCirc&dataset=ref2021_circ&dataobj=".$circ->get_id;
	if( EPrints::Utils::is_set( $self->{processor}->{return_to} ) )
	{
		# note that only REF2021::Overview sets the return_to parameter
		$redirect_url .= "&return_to=".$self->{processor}->{return_to};
	}
	$self->{processor}->{redirect} = $redirect_url; 
}

sub properties_from
{
	my( $self ) = @_;

	$self->SUPER::properties_from();

	my $return_to = $self->{session}->param( 'return_to' );
	$self->{processor}->{return_to} = $return_to if( EPrints::Utils::is_set( $return_to ) );

}

1;
