use v5.22;
use warnings;
use Test::Most;

package Cache::LRU {
    use Data::Checks;
    use Hash::Ordered;
    use lib 'lib';

    sub new ( $class, $max_size : of(UINT) ) {
        return bless {
            cache    => Hash::Ordered->new,
            max_size => $max_size // 20,
        } => $class;
    }

    sub _cache   ($self) { $self->{cache} }
    sub max_size ($self) { $self->{max_size} }
    sub items    ($self) { scalar $self->_cache->keys }

    sub exists : returns(BOOL) ( $self, $key : of(STR) ) {
        return $self->_cache->exists($key);
    }

    sub set ( $self, $key : of(STR), $value : of(DEF) ) {
        $self->_cache->unshift( $key, $value );
        if ( $self->_cache->keys > $self->max_size ) {
            $self->_cache->pop;
        }
        return $self;
    }

    # Returns ANY instead of DEF because we might have a cache miss
    # The !VOID means we can't be called in void context, eliminating
    # a source of obscure bugs
    sub get : returns(ANY & !VOID) ( $self, $key : of(STR) ) {
        return unless $self->_cache->exists($key);
        my $value = $self->_cache->get($key);
        $self->set( $key, $value );
        return $value;
    }
}

# Deep within the code, we have a few checks like this:
#
#     if ((((caller 0)[10] // {})->{'Data::Checks::Parser/mode'}//q{}) ne 'NONE') {$OF_CHECKS}
#
# Originally they were like this:
#
#     if (((caller 0)[10]{'Data::Checks::Parser/mode'}//q{}) ne 'NONE') {$OF_CHECKS}
#
# I don't know exactly what was causing this, but there appears to have been a
# strange interaction between our custom caller and Sub::Uplevel which caused
# (caller 0)[10] to sometimes return undef. Thus, the // {} got appended.
ok my $cache = Cache::LRU->new(4), 'We should be able to create a cache object';
ok !$cache->items,                 '... and it should start out as empty';
is $cache->max_size, 4, '... and it should have a correct max_size';

ok !$cache->exists('one'),            'Our first key should not yet exist';
ok $cache->set( one => [ 1, 2, 3 ] ), 'We should be able o set something in our cache';
ok $cache->exists('one'),             '... but it should exist after we have set it';
is $cache->items, 1, '... and see we have one item in the cache';
is_deeply $cache->get('one'), [ 1, 2, 3 ], '... and we can fetch the item again';

$cache->set( two   => [2] );
$cache->set( three => [3] );
$cache->set( four  => [4] );

is $cache->items, $cache->max_size, 'We should be able to keep adding items to the cache';
$cache->set( five => [5] );
is $cache->items, $cache->max_size, '... but as we add items, we cannot have more items than the max size';
ok !$cache->exists('one'), '... and our oldest key is gone';
ok !$cache->get('one'),    '... and older items should be ejected from the cache';

is_deeply $cache->get('two'), [2], 'We can fetch existing items from teh cache';
$cache->set( six => [6] );
is $cache->items, $cache->max_size, '... but as we add items, we cannot have more items than the max size';
is_deeply $cache->get('two'), [2], '... and the oldest item should not be ejected because we recently fetched it';
ok !$cache->get('three'), '... and older items should be ejected from the cache';
throws_ok { $cache->get('three') }
qr/\QVoid return from call to get() failed/,
  'Calling get() in void context should be fatal';

done_testing;

