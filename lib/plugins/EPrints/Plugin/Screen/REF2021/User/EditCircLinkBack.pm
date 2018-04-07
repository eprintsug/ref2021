package EPrints::Plugin::Screen::REF2021::User::EditCircLinkBack;

# the opposite of EditCircLink, a link between a ref_circ dataobj and a user object

use EPrints::Plugin::Screen::Workflow::Edit;
@ISA = ( 'EPrints::Plugin::Screen::Workflow::Edit' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ stop save /];

	$self->{staff} = 0;

	return $self;
}

sub can_be_viewed
{
        my( $self ) = @_;

        return 0 unless( $self->{session}->config( 'ref2021_enabled' ) );

        return 0 unless( defined $self->{processor}->{dataset} && $self->{processor}->{dataset}->id eq 'ref2021_circ' );

        # sf2 - allow local over-ride of whether a user can view the REF20211 Data page
        if( $self->{session}->can_call( 'ref_can_user_view_ref1' ) )
        {
                my $rc = $self->{session}->call( 'ref_can_user_view_ref1', $self->{session} ) || 0;
                return $rc;
        }

	# just does a mapping between 2 objects, no complex permission required (the screen it redirects to will show any permission error)
	return 1;
}

# properties_from() (called BEFORE from()) will set dataset to 'user' and dataobj to the user being viewed/edited
# from() allows us to redirect to the "real" EditCirc screen
sub from
{
	my( $self ) = @_;

	my $circ = $self->{processor}->{dataobj};
	return unless( defined $circ );

	my $user = $self->{session}->dataset( 'user' )->dataobj( $circ->value( 'userid' ) );
	return unless( defined $user );

	my $redirect_url = $self->{session}->config( 'userhome' )."?screen=Workflow::View&dataset=user&dataobj=".$user->get_id;
	if( EPrints::Utils::is_set( $self->{processor}->{return_to} ) )
	{
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
