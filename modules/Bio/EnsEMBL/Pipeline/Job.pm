
# Object for storing details of an analysis job
#
# Cared for by Michele Clamp  <michele@sanger.ac.uk>
#
# Copyright Michele Clamp
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Pipeline::DBSQL::Job

=head1 SYNOPSIS

=head1 DESCRIPTION

Stores run and status details of an analysis job

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::EnsEMBL::Pipeline::Job;
# use Data::Dumper;

use vars qw(@ISA);
use strict;

# use FreezeThaw qw(freeze thaw);

# Object preamble - inherits from Bio::Root::Object;

use Bio::EnsEMBL::Pipeline::Analysis;
use Bio::EnsEMBL::Pipeline::Status;
use Bio::EnsEMBL::Pipeline::DBSQL::JobAdaptor;

#my $nfs_tmpdir = "/nfs/disk100/humpub1/michele/est2genome/";
my $nfs_tmpdir = "/tmp";


@ISA = qw(Bio::EnsEMBL::Pipeline::DB::JobI Bio::Root::RootI);

sub new {
    my ($class, @args) = @_;
    my $self = bless {},$class;

    my ($adaptor,$dbID,$lsfid,$input_id,$analysis,$stdout,$stderr,$input, $retry_count ) 
	= $self->_rearrange([qw(ADAPTOR
				ID
				LSF_ID
				INPUT_ID
				ANALYSIS
				STDOUT
				STDERR
				INPUT_OBJECT_FILE
				RETRY_COUNT
				)],@args);

    $dbID    = -1 unless defined($dbID);
    $lsfid = -1 unless defined($lsfid);

    $input_id   || $self->throw("Can't create a job object without an input_id");
    $analysis   || $self->throw("Can't create a job object without an analysis object");

    $analysis->isa("Bio::EnsEMBL::Pipeline::Analysis") ||
	$self->throw("Analysis object [$analysis] is not a Bio::EnsEMBL::Pipeline::Analysis");

    $self->dbID         ($dbID);
    $self->adaptor  ($adaptor);
    $self->input_id   ($input_id);
    $self->analysis   ($analysis);
    $self->stdout_file($stdout);
    $self->stderr_file($stderr);
    $self->input_object_file($input);
    $self->retry_count( $retry_count );
    $self->LSF_id( $lsfid );

    return $self;
}


=head2 create_by_analysis_inputId

  Title   : create_by_analysis_inputId
  Usage   : $class->create_by.....
  Function: Creates a job given an analysis object and an inputId
            Recommended way of creating job objects!
  Returns : a job object, not connected to db
  Args    : 

=cut

sub create_by_analysis_inputId {
  my $class = shift;
  my $analysis = shift;
  my $inputId = shift;

  my $job = Bio::EnsEMBL::Pipeline::Job->new
    ( -input_id => $inputId,
      -analysis => $analysis,
    );
  $job->make_filenames;
  return $job;
}



=head2 dbID

  Title   : dbID
  Usage   : $self->dbID($id)
  Function: get set the dbID for this object, only used by Adaptor
  Returns : int
  Args    : int

=cut


sub dbID {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{_dbID} = $arg;
    }
    return $self->{_dbID};

}

=head2 adaptor

  Title   : adaptor
  Usage   : $self->adaptor
  Function: get database adaptor, set only for constructor and adaptor usage. 
  Returns : 
  Args    : 

=cut


sub adaptor {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{_adaptor} = $arg;
    }
    return $self->{_adaptor};

}



=head2 input_id

  Title   : input_id
  Usage   : $self->input_id($id)
  Function: Get/set method for the id of the input to the job
  Returns : int
  Args    : int

=cut


sub input_id {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{_input_id} = $arg;
    }
    return $self->{_input_id};
}

=head2 analysis

  Title   : analysis
  Usage   : $self->analysis($anal);
  Function: Get/set method for the analysis object of the job
  Returns : Bio::EnsEMBL::Pipeline::Analysis
  Args    : bio::EnsEMBL::Pipeline::Analysis

=cut

sub analysis {
    my ($self,$arg) = @_;
    if (defined($arg)) {
	$self->throw("[$arg] is not a Bio::EnsEMBL::Pipeline::Analysis object" ) 
            unless $arg->isa("Bio::EnsEMBL::Pipeline::Analysis");

	$self->{_analysis} = $arg;
    }
    return $self->{_analysis};

}

=head2 runLocally
=head2 runRemote( boolean withDB, queue )
=head2 runInLSF

  Title   : running
  Usage   : $self->run...;
  Function: runLocally doesnt submit to LSF
            runInLSF is like runLocally, but doesnt redirect STDOUT and 
            STDERR. 
            runRemote starts in LSF via the runner.pl script.
  Returns : 
  Args    : 

=cut

sub runLocally {
  my $self = shift;

  $self->throw( "Not implemented" );
}

sub runRemote {
  my $self = shift;
  my $queue = shift;
  my $useDB = shift;

  local *SUB;

  if( !defined $self->adaptor ) {
    $self->throw( "Cannot run remote without db connection" );
  }

  my $db = $self->adaptor->db;
  my $host = $db->host;
  my $username = $db->username;
  my $dbname = $db->dbname;
  my $cmd;

  my $runner = ( $0 =~ s:/[^/]*$:runner.pl: );
  $cmd = "bsub -q ".$queue." -o ".$self->stdout_file.
    " -e ".$self->stderr_file." ";

  if( ! defined $useDB ) {
    $useDB = 1;
  }

  if( $useDB ) {
    # find out db details from adaptor
    # generate the lsf call
    $cmd .= $runner." -host $host -dbuser $username -dbname $dbname -job ".$self->dbID 
    
  } else {
    # make the object
    # call its get input method..
    # freeze it
    $self->throw( "useDB=0 not implemented yet." );
  }
  
  open (SUB,"$cmd |");
  
  while (<SUB>) {
    if (/Job <(\d+)>/) {
      $self->LSF_id($1);
      # print (STDERR $_);
    }
  }
  close(SUB);

  if( $self->LSF_id == -1 ) {
    print STDERR ( "Couldnt submit ".$self->dbID." to LSF" );
  } else {
    $self->set_status( "SUBMITTED" );
  }

  $self->adaptor->update( $self );
}

# question, when to submit the success report to the db?
# we have to parse the output of LSF anyway....
sub runInLSF {
  my $self = shift;
  my $module = $self->analysis->module;
  my $rdb;
  

  eval {
    if( $module =~ /::/ ) {
      $module =~ s/::/\//g;
      require "${module}.pm";
      $rdb = "${module}"->new
	( -analysis => $self->analysis,
	  -input_id => $self->inputId,
	  -dbobj => $self->adaptor->db );
    } else {
      require "Bio/EnsEMBL/Pipeline/RunnableDB/${module}.pm";
      $rdb = "Bio::EnsEMBL::Pipeline::RunnableDB::${module}"->new
	( -analysis => $self->analysis,
	  -input_id => $self->inputId,
	  -dbobj => $self->adaptor->db );
    }
    $self->set_status( "READING" );
    $rdb->fetch_input;
    $self->set_status( "RUNNING" );
    $rdb->run;
    $self->set_status( "WRITING" );
    $rdb->write_output;
    $self->set_status( "SUCCESSFUL" );
  }; 
  if( $@ ) {
# print STDERR ("Problems with $module\n");
    $self->set_status( "FAILED" );
    die "Problems with $module." ;
  }
}


=head2 resultToDb

  Title   : resultToDB
  Usage   : $self->resultToDb;
  Function: Find if job finished by looking at STDOUT and STDERR
            try set current_status according to what you find.
            write_output on the runnablDB is recommended way of 
            putting results into the DB.
            DONT use when job started with db connection.
  Returns : false, if job seems not to be finished on the remote side..
  Args    : 

=cut

sub resultToDb {
  my $self = shift;
  $self->throw( "Not implemented yet." );
}


sub write_object_file {
    my ($self,$arg) = @_;

    $self->throw("No input object file defined") unless defined($self->input_object_file);

    if (defined($arg)) {
	my $str = FreezeThaw::freeze($arg);
	open(OUT,">" . $self->input_object_file) || $self->throw("Couldn't open object file " . $self->input_object_file);
	print(OUT $str);
	close(OUT);
    }
}

=head2 LSF_id

  Title   : LSF_id
  Usage   : $self->LSF_id($id)
  Function: Get/set method for the LSF id of the job
  Returns : int
  Args    : int

=cut


sub LSF_id {
    my ($self,$arg) = @_;

    return $self->_LSFJob->id($arg);
}


=head2 set_status

  Title   : set_status
  Usage   : my $status = $job->set_status
  Function: Sets the job status
  Returns : nothing
  Args    : Bio::EnsEMBL::Pipeline::Status

=cut

sub set_status {
  my ($self,$arg) = @_;
  
  $self->throw("No status input" ) unless defined($arg);
  
  
  if (!(defined($self->adaptor))) {
    $self->warn("No database connection.  Can't set status to $arg");
    return;
  }
  
  return $self->adaptor->set_status( $self, $arg );
}


=head2 current_status

  Title   : current_status
  Usage   : my $status = $job->current_status
  Function: Get/set method for the current status
  Returns : Bio::EnsEMBL::Pipeline::Status
  Args    : Bio::EnsEMBL::Pipeline::Status

=cut

sub current_status {
  my ($self,$arg) = @_;
  
  if( ! defined( $self->adaptor )) {
    return undef;
  }
 
  return $self->adaptor->current_status( $self, $arg );
}

=head2 get_all_status

  Title   : get_all_status
  Usage   : my @status = $job->get_all_status
  Function: Get all status objects associated with this job
  Returns : @Bio::EnsEMBL::Pipeline::Status
  Args    : @Bio::EnsEMBL::Pipeline::Status

=cut

sub get_all_status {
  my ($self) = @_;
  
  if( $self->adaptor ) {
    return $self->adaptor->get_all_status( $self );
  } else {
    return undef;
  }
}


sub make_filenames {
  my ($self) = @_;
  
  my @files = $self->get_files( $self->input_id,,"obj","out","err" );
  for (@files) {
    open( FILE, ">".$_ ); close( FILE );
  }
 
  $self->input_object_file($files[0]);
  $self->stdout_file($files[1]);
  $self->stderr_file($files[2]);
}


sub get_files {
  my ($self,$stub,@exts) = @_;
  my @result;
  my @files;
  my $dir;

  my $count = 0;

  while( 1 ) {
    my $num = int(rand(10));
    $dir = $nfs_tmpdir . "/$num/";
    if( ! -e $dir ) {
      system( "mkdir $dir" );
    }
    opendir( DIR, $dir );
    @files = readdir( DIR );
    if( scalar( @files ) > 10000 ) {
      if( $count++ > 10 ) {
	$self->throw("10000 files in directory. Can't make a new file");
      } else {
	next;
      }
    } else {
      last;
    }
  }
  $count = 0;
  # Should check disk space here.
  
 OCCU: while( $count++ < 10 ) { 
    my $rand  = int(rand(100000));
    @result = ();
    foreach my $ext ( @exts ) {
      my $file  = $dir . $stub . "." . $rand . "." . $ext;
      if( -e $file ) {
	next OCCU;
      }
      push( @result, $file );
    }
    last;
  }

  if( $count > 9 ) {
    $self->throw( "File generation problem in $dir" );
  }
  return @result;
}



=head2 stdout_file

  Title   : stdout_file
  Usage   : my $file = $self->stdout_file
  Function: Get/set method for stdout.
  Returns : string
  Args    : string

=cut

sub stdout_file {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{_stdout_file} = $arg;
    }
    return $self->{_stdout_file};
}

=head2 stderr_file

  Title   : stderr_file
  Usage   : my $file = $self->stderr_file
  Function: Get/set method for stderr.
  Returns : string
  Args    : string

=cut

sub stderr_file {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{_stderr_file} = $arg;
    }
    return $self->{_stderr_file};
}


=head2 input_object_file

  Title   : input_object_file
  Usage   : my $file = $self->input_object_file
  Function: Get/set method for the input object file
  Returns : string
  Args    : string

=cut

sub input_object_file {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{_input_object_file} = $arg;
    }
    return $self->{_input_object_file};
}

=head2 LSF_id

  Title   : LSF_id
  Usage   : 
  Function: Get/set method for the LSF_id
  Returns : 
  Args    : 

=cut

sub LSF_id {
  my ($self, $arg) = @_;
  (defined $arg) &&
    ( $self->{_lsfid} = $arg );
  $self->{_lsfid};
}

=head2 retry_count

  Title   : retry_count
  Usage   : 
  Function: Get/set method for the retry_count
  Returns : 
  Args    : 

=cut

sub retry_count {
  my ($self, $arg) = @_;
  (defined $arg) &&
    ( $self->{_retry_count} = $arg );
  $self->{_retry_count};
}

sub remove {
  my $self = shift;
  
  if( -e $self->stdout_file ) { unlink( $self->stdout_file ) };
  if( -e $self->stderr_file ) { unlink( $self->stderr_file ) };
  if( -e $self->object_file ) { unlink( $self->object_file ) };

  if( defined $self->adaptor ) {
    $self->adaptor->remove( $self );
  }
}

1;





