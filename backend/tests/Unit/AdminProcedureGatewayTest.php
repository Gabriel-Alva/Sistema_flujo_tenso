<?php

namespace Tests\Unit;

use App\Core\Database\AdminProcedureGateway;
use InvalidArgumentException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class AdminProcedureGatewayTest extends TestCase
{
    #[DataProvider('invalidCalls')]
    public function test_unapproved_or_misbound_procedures_are_rejected(
        string $procedure,
        array $bindings,
    ): void {
        $this->expectException(InvalidArgumentException::class);

        (new AdminProcedureGateway)->rows($procedure, $bindings);
    }

    /** @return array<string, array{string, array<int, mixed>}> */
    public static function invalidCalls(): array
    {
        return [
            'unknown procedure' => ['sp_admin_drop_data', []],
            'wrong parameter count' => ['sp_admin_dashboard', ['unexpected']],
        ];
    }
}
