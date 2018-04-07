package EPrints::Plugin::Screen::REF2021::User::Edit;

use EPrints::Plugin::Screen::Workflow::Edit;
use EPrints::Plugin::Screen::REF2021;

@ISA = qw(
	EPrints::Plugin::Screen::Workflow::Edit
        EPrints::Plugin::Screen::REF2021
);

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ stop save next prev /];

	$self->{appears} = [
                {
                        place => "dataobj_view_actions",
                        position => 1650,
                },
		{
			place => "ref2021_listing_user_actions",
			position => 100,
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

        # sf2 - allow local over-ride of whether a user can view the REF20211 Data page
        if( $self->{session}->can_call( 'ref_can_user_view_ref1' ) )
        {
                my $rc = $self->{session}->call( 'ref_can_user_view_ref1', $self->{session} ) || 0;
                return $rc;
        }

	# i don't think non-staff should be able to set their uoa:
	return $self->{session}->current_user->allow( 'user/staff/edit', $self->{processor}->{user} );
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

	$self->{processor}->{dataset} = $session->dataset( 'user' );

	$self->{processor}->{return_to} = $session->param( 'return_to' );
	
	$self->EPrints::Plugin::Screen::REF2021::properties_from;
	$self->SUPER::properties_from;
}

sub from
{
	my( $self ) = @_;

	if( defined $self->{processor}->{internal} )
	{
		my $from_ok = $self->workflow->update_from_form( $self->{processor},undef,1 );
		$self->uncache_workflow;
		return unless $from_ok;
	}

	$self->EPrints::Plugin::Screen::from;
	$self->EPrints::Plugin::Screen::REF2021::from;
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
                        "ref2021",
                        %opts );
        }

        return $self->{processor}->{$cache_id};
}

sub render_title
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	$chunk->appendChild( $self->html_phrase( 'title' ) );

	if( defined $self->{processor}->{dataobj} )
	{
		$chunk->appendChild( $self->{session}->make_text( " - " ) );
		$chunk->appendChild( $self->{processor}->{dataobj}->render_value( 'name' ) );
	}

	return $chunk;
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

        my $return_to = $self->{processor}->{return_to};

        if( EPrints::Utils::is_set( $return_to ) )
        {
                $return_to =~ s/^Screen:://g;
                return $return_to;
        }

        return $self->SUPER::view_screen;
}


1;


