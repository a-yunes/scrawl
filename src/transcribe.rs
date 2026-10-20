//! On-device transcription through the bundled Apple Speech helper.

use std::path::Path;


use crate::audio::RecordedAudio;
use crate::model::TranscriptData;

pub const LOCAL_ENGINE_TITLE: &str = "Apple Speech";

/// Missing microphones and a failed transcriber never prevent saving a bundle.
pub fn transcribe(wav: Option<&Path>, audio: Option<&RecordedAudio>) -> TranscriptData {
    let (Some(wav), Some(audio)) = (wav, audio.filter(|audio| audio.sample_count > 0)) else {
        return TranscriptData {
            source: "none".into(),
            ..Default::default()
        };
    };
    let live = audio.live.take();
    live.and_then(|live| finish_live(live, audio))
        .unwrap_or_else(|| apple(wav))
}

/// The transcript made while recording, or `None` (logged) to transcribe the WAV instead.
fn finish_live(
    live: crate::live_transcribe::Live,
    audio: &RecordedAudio,
) -> Option<TranscriptData> {
    match live.finish(&audio.wav_bytes) {
        Ok(done) => {
            crate::capture::scrawl_log(format!(
                "Live transcription: {} words, {} of {} ms streamed, tail {} ms",
                done.transcript.words.len(),
                done.streamed_samples as u64 * 1_000 / 16_000,
                audio.duration_ms,
                done.tail_ms
            ));
            Some(done.transcript)
        }
        Err(error) => {
            crate::capture::scrawl_log(format!(
                "Live transcription failed, transcribing the recording: {error:#}"
            ));
            None
        }
    }
}

fn apple(wav: &Path) -> TranscriptData {
    let transcript = crate::helper::transcribe(wav).unwrap_or_else(|error| {
        crate::capture::scrawl_log(format!("{LOCAL_ENGINE_TITLE} failed: {error:#}"));
        TranscriptData {
            source: "offline".into(),
            missing: Some(crate::model::MissingTranscript {
                reason: format!("{LOCAL_ENGINE_TITLE} failed ({error:#})."),
                retry: false,
            }),
            ..Default::default()
        }
    });
    if let Some(missing) = &transcript.missing {
        crate::capture::scrawl_log(format!("No transcript: {}", missing.reason));
        if missing.retry {
            crate::speech_model::ensure();
        }
    }
    transcript
}
