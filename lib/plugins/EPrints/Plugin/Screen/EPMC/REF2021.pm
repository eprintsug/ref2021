package EPrints::Plugin::Screen::EPMC::REF2021;

@ISA = ( 'EPrints::Plugin::Screen::EPMC' );

use strict;

sub new
{
      my( $class, %params ) = @_;

      my $self = $class->SUPER::new( %params );

      $self->{actions} = [qw( enable disable ) ];
      $self->{disable} = 0; # always enabled, even in lib/plugins

      $self->{package_name} = "ref2021";

      return $self;
}

=item $screen->action_enable( [ SKIP_RELOAD ] )

Enable the L<EPrints::DataObj::EPM> for the current repository.

If SKIP_RELOAD is true will not reload the repository configuration.

=cut

sub action_enable
{
	my( $self, $skip_reload ) = @_;

	$self->SUPER::action_enable( $skip_reload );

	# Add the REF2021 UoAs:
	$self->add_ref2021_uoas();

	# Change the labels for UoA's A1 to B9 if necessary:
	$self->update_ref2021_labels();

	# If people are coming from an upgrade, they might need the new UoA 'Z' (added in v1.1)
	$self->add_ref2021_uoa_z();

	# re-commit ref2021_selection dataset (pre-populate ref2021_selection.output_type - added in v1.1)
	$self->recommit_ref_selections();

	# bug in EPrints that prevents the addition of new fields (https://github.com/eprints/eprints/issues/44)
	$self->update_datasets();

	$self->reload_config if !$skip_reload;
}

# v1.0 - REF2021 UoAs
sub add_ref2021_uoas
{
	my( $self ) = @_;
	
	my $repo = $self->{repository};
	
	# First check that this subject tree doesn't already exist...
	my $ds = $repo->dataset( 'subject' );
	my $test_subject_id = $ds->dataobj( 'ref2021_uoas' );

	if( !defined $test_subject_id )
	{
		my $filename = $repo->config( 'archiveroot' ).'/cfg/subjects_uoa';
		if( -e $filename )
		{
			my $plugin = $repo->plugin( 'Import::FlatSubjects' );
			my $list = $plugin->input_file( dataset => $repo->dataset( 'subject' ), filename=>$filename );
			$repo->dataset( 'subject' )->reindex( $repo );
		}
	}
}

# v1.1 - adds UoA 'Z' for people not yet affiliated (but who want to start selecting etc)
sub add_ref2021_uoa_z
{
	my( $self ) = @_;
	
	my $repo = $self->{repository};

	my $lang = $repo->config( "defaultlanguage" );

	my $uoa_z = {
		subjectid => 'ref2021_z',
		name_name => [ 'Z - Unaffiliated' ],
		name_lang => [ $lang ],
		parents => [ 'ref2021_uoas' ],
		depositable => 'TRUE'
	};

	my $subds = $repo->dataset( 'subject' ) or return;

	# has the UoA Z already been imported?
	return if( defined $subds->dataobj( 'ref2021_z' ) );

	my $z_object = $subds->create_dataobj( $uoa_z );

	if( defined $z_object )
	{
		$z_object->commit;
		$subds->reindex( $repo );
	}
}

# v1.2 - updates the labels for UoA's A1 to B9 (to A01 ... B09) to fix an ordering issue
sub update_ref2021_labels
{
	my( $self ) = @_;

	my $repo = $self->{repository};

        my $subds = $repo->dataset( 'subject' );
        my $test_subject = $subds->dataobj( 'ref2021_a1' ) or return;

	my $test_render = EPrints::Utils::tree_to_utf8( $test_subject->render_value( 'name' ) );

	if( defined $test_render && $test_render =~ /^A01/ )
	{
		return; 	# already done
	}

	my $ids_to_fix = [qw/ a1 a2 a3 a4 a5 a6 b7 b8 b9 /];

	foreach my $id ( @$ids_to_fix )
	{
		my $subject = $subds->dataobj( "ref2021_$id" ) or next;

		my $names = $subject->value( 'name' );

		my $name;	
		# subject field may exist in different formats hence all the tests below:
		if( ref( $names ) eq 'ARRAY' )
		{
			if( scalar( @$names ) > 1 )
			{
				#print "ERROR! More than one name defined...?\n";
				next;
			}

			$name = $names->[0];

			if( ref( $name ) eq 'HASH' )
			{
				# probably a multi-lang with {name,lang}

				my @keys = grep { !/^name$/ } keys %$name;

				my $new_name = &fix_label( $name->{name} ) or next;

				my $h = { name => $new_name };
				foreach(@keys)
				{
					$h->{$_} = $name->{$_};
				}

				$subject->set_value( 'name', [ $h ] );

			}
			else
			{
				# multiple, simple field
				my $new_name = &fix_label( $name ) or next;
				$subject->set_value( [ $new_name ] );
			}
		}
		elsif( ref( $names ) eq 'HASH' )
		{
			# compound field
			my $new_name = &fix_label( $name->{name} ) or next;	
			my @keys = grep { !/^name$/ } keys %$name;
			my $h = { name => $new_name };
			foreach(@keys)
			{
				$h->{$_} = $name->{$_};
			}
			$subject->set_value( 'name', $h );
		}
		else
		{
			# simple field
			my $new_name = &fix_label( $name ) or next;
			$subject->set_value( 'name', $new_name );
		}
		
		$subject->commit;
	}
}

sub fix_label
{
	my( $value ) = @_;

	if( $value =~ /^([AB])(\d)(.*)$/ )
	{
		return undef if( $2 eq '0' );	# already fixed perhaps?
		my $new_name = $1."0".$2.$3;
		return $new_name;
	}
	
	return undef;
}

# Note: recommits only the current Benchmark
sub recommit_ref_selections
{
	my( $self ) = @_;

	my $repo = $self->{repository};

	my $benchmark = EPrints::DataObj::REF2021Benchmark->default( $repo ) or return;

	my $list = $benchmark->selections() or return;
        
	$list->map( sub {
                my( undef, undef, $item ) = @_;
                
		$item->commit( 1 );
        } );

}

# v1.3
sub update_datasets
{
	my( $self ) = @_;
	
	my $repo = $self->{repository};

	my $iepm = $repo->dataset( "epm" )->dataobj( 'ref2021' ) or return;

        foreach my $repoid ( $iepm->repositories )
        {
                my $repo2 = EPrints->new->repository( $repoid );
		
		foreach( 'ref2021_selection', 'ref2021_circ', 'ref2021_benchmark', 'ref2021_environment' )
		{
			my $dataset = $repo2->dataset( $_ );
			if( !$repo2->get_database->has_dataset( $dataset ) )
			{
				$repo2->get_databse->create_dataset_tables( $dataset );
			}
			foreach my $field ($dataset->get_fields)
			{
				next if defined $field->get_property( "sub_name" );
				if( !$repo2->get_database->has_field( $dataset, $field ) )
				{
					$repo2->get_database->add_field( $dataset, $field );
				}
			}
		}
        }
}



=item $screen->action_disable( [ SKIP_RELOAD ] )

Disable the L<EPrints::DataObj::EPM> for the current repository.

If SKIP_RELOAD is true will not reload the repository configuration.

=cut

sub action_disable
{
	my( $self, $skip_reload ) = @_;

	return $self->SUPER::action_disable( $skip_reload );
}

sub properties_from
{
	my( $self ) = @_;

	$self->SUPER::properties_from;

	unless( defined $self->{processor}->{dataobj} )
	{
		$self->{processor}->{dataobj} = $self->{session}->dataset( 'epm' )->dataobj( $self->{package_name} );
	}
}

1;

