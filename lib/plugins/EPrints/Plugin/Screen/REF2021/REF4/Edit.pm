package EPrints::Plugin::Screen::REF2021::REF4::Edit;

use EPrints::Plugin::Screen::Workflow::Edit;

@ISA = qw(
	EPrints::Plugin::Screen::Workflow::Edit
);

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	delete $self->{appears};

	$self->{staff} = 0;

	return $self;
}

sub properties_from
{
        my( $self ) = @_;

        my $session = $self->{session};
	$self->{processor}->{return_to} = $session->param( 'return_to' );
	$self->SUPER::properties_from;
}


sub hidden_bits
{
        my( $self ) = @_;

        return(
                $self->SUPER::hidden_bits,
                return_to => $self->{processor}->{return_to}
        );
}

sub view_screen
{
	my( $self ) = @_;

	return $self->{processor}->{return_to} if( defined $self->{processor}->{return_to} );

	return $self->SUPER::view_screen;
}

1;

