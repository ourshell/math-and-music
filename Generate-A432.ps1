Function ToneGenerator($frequency, $TimeStep, $samples, $volume, $Duration) {
    $sine = 2 * [System.Math]::PI * $frequency * $TimeStep

    for ($step = 0; $step -lt $samples; $step++) {
        # Time in seconds for the current step
        $currentTime = $step * $TimeStep

        # Calculate fade-out factor (exponential decay)
        $fadeFactor = if ($currentTime -lt $Duration) {
            [System.Math]::Exp(-5 * $currentTime / $Duration)  # Smooth exponential decay
        } else {
            0  # Fully faded out
        }

        # Harmonics and wave calculation
        $wave = [System.Math]::Sin($sine * $step) + 
                [System.Math]::Sin(2 * $sine * $step) / 3.16227766016838 +
                [System.Math]::Sin(3 * $sine * $step) / 6.20127870518404 +
                [System.Math]::Sin(4 * $sine * $step) / 10 +
                [System.Math]::Sin(5 * $sine * $step) / 14.4865192364027 +
                [System.Math]::Sin(6 * $sine * $step) / 19.6101651138814

        # Apply fade-out and cubic soft-clipping
        $output = $volume * $wave * $wave * $wave * $fadeFactor

        # Write to WAV file as int16
        $Script:mWriter.Write([int16]$output)
    }
}

$Path = $MyInvocation.MyCommand.Path

# Configuration
$SamplePath = $SamplePath = $Path.Substring(0, $Path.LastIndexOf("\")) + "\Tone-A440.wav"
$Duration = 8
$Frequency = 440

# WAV Header Setup
[int]$msDuration = $Duration * 1000
[int]$volume = 26000 # [uint16]::MaxValue -shr 2 # Max volume scaled for int16
[int]$formatChunkSize = 16; # Format chunk size
[int]$headerSize = 8;
[int16]$formatType = 1; # PCM format
[int16]$tracks = 1; # Mono
[int]$BitRate = 44100;
[double]$TimeStep = 1 / $BitRate
[int16]$bitsPerSample = 16;
[int16]$frameSize = [System.Math]::Truncate($tracks * ($bitsPerSample + 7) / 8)
[int]$bytesPerSecond = $BitRate * $frameSize
[int]$waveSize = 4
[int]$Samples = $BitRate * $msDuration / 1000
[int]$dataChunkSize = $samples * $frameSize
[int]$fileSize = $waveSize + $headerSize + $formatChunkSize + $headerSize + $dataChunkSize

# RIFF / WAV Header
[byte[]]$RIFF = @()
$RIFF += [System.Text.Encoding]::ASCII.GetBytes("RIFF")
$RIFF += [System.BitConverter]::GetBytes($fileSize)
$RIFF += [System.Text.Encoding]::ASCII.GetBytes("WAVE")
$RIFF += [System.Text.Encoding]::ASCII.GetBytes("fmt ")
$RIFF += [System.BitConverter]::GetBytes($formatChunkSize)
$RIFF += [System.BitConverter]::GetBytes($formatType)
$RIFF += [System.BitConverter]::GetBytes($tracks)
$RIFF += [System.BitConverter]::GetBytes($BitRate)
$RIFF += [System.BitConverter]::GetBytes($bytesPerSecond)
$RIFF += [System.BitConverter]::GetBytes($frameSize)
$RIFF += [System.BitConverter]::GetBytes($bitsPerSample)
$RIFF += [System.Text.Encoding]::ASCII.GetBytes("data")
$RIFF += [System.BitConverter]::GetBytes($dataChunkSize)

# Generate and Write Tone
$mStream = New-Object IO.MemoryStream
$mWriter = [System.IO.BinaryWriter]::new($mStream)
$mWriter.Write($RIFF)

ToneGenerator $Frequency $TimeStep $Samples $volume $Duration

$mWriter.Close()

$fStream = [System.IO.FileStream]::new($SamplePath, [System.IO.FileMode]::Create)
$fWriter = [System.IO.BinaryWriter]::new($fStream)
$fWriter.Write($mStream.ToArray())

$mStream.Close()
$mWriter.Close()
$fStream.Close()
$fWriter.Close()
