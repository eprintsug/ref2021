
package EPrints::Plugin::Screen::REF2021::User::EditUoA;

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
		}
	];

	$self->{staff} = 0;

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0 unless( $self->{session}->config( 'ref2021_enabled' ) );

	return 0 unless( defined $self->{processor}->{dataset} && $self->{processor}->{dataset}->id eq 'user' );

	return 1 if( defined $self->{session}->current_user && $self->{session}->current_user->has_role( 'ref/select_champions' ) );
	return 0;
}

sub properties_from
{
        my( $self ) = @_;

        my $session = $self->{session};

        $self->{processor}->{dataset} = $session->dataset( 'user' );

        $self->SUPER::properties_from;
}

sub workflow
{
        my( $self, $staff ) = @_;

        my $cache_id = "workflow";
        $cache_id.= "_staff" if( $staff );

        if( !defined $self->{processor}->{$cache_id} )
        {
                my %opts = (
                        item => $self->{processor}->{dataobj},
                        session => $self->{session} );
                $opts{STAFF_ONLY} = [$staff ? "TRUE" : "FALSE","BOOLEAN"];
                $self->{processor}->{$cache_id} = EPrints::Workflow->new(
                        $self->{session},
                        "2021_uoa_champion",
                        %opts );
        }

        return $self->{processor}->{$cache_id};
}

1;


