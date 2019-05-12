package ch.ffhs.elcy.clcoaddress.repository;

import ch.ffhs.elcy.clcoaddress.model.Address;
import org.springframework.data.repository.CrudRepository;

public interface AddressRepository extends CrudRepository<Address, Long> {
}
