<?php

namespace App\Services;

use Aws\Sns\SnsClient;
use Illuminate\Support\Facades\Log;

class SnsService
{
    protected ?SnsClient $client = null;

    public function __construct()
    {
        // Uses EC2 IAM Role credentials automatically on EC2.
        // Falls back to .env keys locally (if set).
        $this->client = new SnsClient([
            'version' => 'latest',
            'region'  => config('services.sns.region', 'eu-central-1'),
        ]);
    }

    public function publish(string $subject, string $message): void
    {
        $topicArn = config('services.sns.topic_arn');

        if (!$topicArn) {
            Log::info("SNS topic not configured. Would publish: {$subject}");
            return;
        }

        try {
            $this->client->publish([
                'TopicArn' => $topicArn,
                'Subject'  => $subject,
                'Message'  => $message,
            ]);
        } catch (\Throwable $e) {
            Log::error('SNS publish failed: ' . $e->getMessage());
        }
    }
}