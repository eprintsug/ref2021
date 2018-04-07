package EPrints::Plugin::Export::REF2021::REF4_XML;

# XML Exporter for REF4a/b/c

use EPrints::Plugin::Export::REF2021::REF_XML;

@ISA = ( "EPrints::Plugin::Export::REF2021:REF_XML" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "REF2021 - XML";
	$self->{accept} = [ 'report2021/ref4' ];
	$self->{visible} = 'staff';
	$self->{suffix} = ".xml";
	$self->{mimetype} = "text/xml";
        $self->{advertise} = $self->{enable} = EPrints::Utils::require_if_exists( "HTML::Entities" ) ? 1:0;

	return $self;
}

sub output_list
{
        my( $plugin, %opts ) = @_;
	
	my $session = $plugin->{session};

	my $institution = $plugin->escape_value( $session->config( 'ref2021', 'institution' ) || $session->phrase( 'archive_name' ) );
	my $action = $session->config( 'ref2021', 'action' ) || 'Update';

print <<HEADER;
<?xml version="1.0" encoding="utf-8"?>
<ref2021Data xmlns="http://www.ref.ac.uk/schemas/ref2021data">
	<institution>$institution</institution>
	<submissions>
HEADER

	# REF4: iterate over the entire list, pre-calculate what needs to be
	# $degrees->{$uoa}->{$year} = 12;
	# $income->{$uoa}->{$source_id}->{$year} = 123_456;
	# $multiple->{$uoa} = 1 or 0 if it's multiple submission;

	my $degrees = {};
	my $incomes = {};
	my $incomes_kind = {};
	my $multiple = {};
	my @uoas;
	my $current_uoa = undef;

	$opts{list}->map( sub {
		my( undef, undef, $dataobj ) = @_;

		# must know the year
		my $year = $dataobj->value( 'year' ) or return;
		
		my $uoa = $plugin->get_current_uoa( $dataobj );
		return unless( defined $uoa );

		if( !defined $current_uoa || ( "$current_uoa" ne "$uoa" ) )
		{
			$current_uoa = $uoa;
			push @uoas, $uoa;
		}

		# degrees awarded
		$degrees->{$uoa}->{$year} = $dataobj->value( 'degrees' );

		# incomes
		foreach( @{$dataobj->value( 'income' )||[]} )
		{
			my $src = $_->{source} or next;
			my $value = $_->{value} or next;
			$src =~ s/^(\d+)_.*$/$1/g;
			$incomes->{$uoa}->{int($src)}->{$year} += $value;
		}

		# incomes in kind
		foreach( @{$dataobj->value( 'income_in_kind' )||[]} )
		{
			my $src = $_->{source} or next;
			my $value = $_->{value} or next;
			$src =~ s/^(\d+)_.*$/$1/g;
			$incomes_kind->{$uoa}->{int($src)}->{$year} += $value;
		}
	} );

	foreach my $uoa (@uoas)
	{
		my( $hefce_uoa_id, $is_multiple ) = $plugin->parse_uoa( $uoa );
		next unless( defined $hefce_uoa_id );

		my $multiple = "";
		if( EPrints::Utils::is_set( $is_multiple ) )
		{
			$multiple = "<multipleSubmission>$is_multiple</multipleSubmission>";
		}

		print <<OPENING;
	<submission>
		<unitOfAssessment>$hefce_uoa_id</unitOfAssessment>
		$multiple
		<environment>

OPENING

		# REF4a
		my @degrees;
		foreach my $year (sort keys %{$degrees->{$uoa}||{}} )
		{

			my $total = $degrees->{$uoa}->{$year};
			next unless( EPrints::Utils::is_set( $total ) && $total =~ /^\d+$/ );

			push @degrees, "<doctoralsAwarded>\n<year>$year</year>\n<degreesAwarded>$total</degreesAwarded>\n</doctoralsAwarded>";
		}
		if( scalar( @degrees ) )
		{
			print "<researchDoctoralsAwarded>\n".join("\n",@degrees)."\n</researchDoctoralsAwarded>\n";
		}

		# REF4b
		my @incomes;
		foreach my $source (sort keys %{$incomes->{$uoa}||{}})
		{
			my $done_any = 0;
			foreach my $year ( sort keys %{$incomes->{$uoa}->{$source}||{}} )
			{
				my $value = $incomes->{$uoa}->{$source}->{$year} or next;
				if( !$done_any )
				{
					push @incomes, "<income>\n<source>$source</source>";
					$done_any++;
				}
				push @incomes, "<Income".$year.">$value</Income".$year.">";
			}
			push @incomes, "\n</income>\n" if( $done_any );
		}
		if( scalar( @incomes ) )
		{
			print "<researchIncome>\n".join( "\n", @incomes )."\n</researchIncome>\n";
		}

		# REF4c
		my @incomes_kind;
		foreach my $source (sort keys %{$incomes_kind->{$uoa}||{}})
		{
			my $done_any = 0;
			foreach my $year ( sort keys %{$incomes_kind->{$uoa}->{$source}||{}} )
			{
				my $value = $incomes_kind->{$uoa}->{$source}->{$year} or next;
				if( !$done_any )
				{
					push @incomes_kind, "<source>$source</source>";
					$done_any++;
				}
				push @incomes_kind, "<Income".$year.">$value</Income".$year."/>";
			}
			push @incomes, "\n</income>\n" if( $done_any );
		}
		if( scalar( @incomes_kind ) )
		{
			print "<researchIncomeInKind>\n".join( "\n", @incomes_kind )."\n</researchIncomeInKind>\n";
		}
		
		print <<CLOSING;
		</environment>
	</submission>
CLOSING

	}
		print <<FOOTER;
    </submissions>
</ref2021Data>
FOOTER
}

1;
