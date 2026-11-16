<?php

namespace App\Modules\Orders\Enums;

enum OrderType: string
{
    case Salon = 'SALON';
    case Llevar = 'LLEVAR';
    case Delivery = 'DELIVERY';
}
