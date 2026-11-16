<?php

namespace App\Core\Exceptions;

use Symfony\Component\HttpKernel\Exception\HttpException;

class DomainException extends HttpException
{
    /**
     * @param  array<string, array<int, string>>  $fieldErrors
     */
    public function __construct(
        public readonly string $errorCode,
        string $message,
        int $status = 409,
        public readonly array $fieldErrors = [],
    ) {
        parent::__construct($status, $message);
    }
}
