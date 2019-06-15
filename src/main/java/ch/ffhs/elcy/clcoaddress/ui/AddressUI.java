package ch.ffhs.elcy.clcoaddress.ui;

import ch.ffhs.elcy.clcoaddress.model.Address;
import ch.ffhs.elcy.clcoaddress.repository.AddressRepository;
import com.vaadin.flow.component.Component;
import com.vaadin.flow.component.button.Button;
import com.vaadin.flow.component.formlayout.FormLayout;
import com.vaadin.flow.component.grid.Grid;
import com.vaadin.flow.component.orderedlayout.HorizontalLayout;
import com.vaadin.flow.component.textfield.TextField;
import com.vaadin.flow.data.binder.Binder;
import com.vaadin.flow.router.AfterNavigationEvent;
import com.vaadin.flow.router.AfterNavigationListener;
import com.vaadin.flow.router.Route;
import com.vaadin.flow.spring.annotation.SpringComponent;
import com.vaadin.flow.spring.annotation.UIScope;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.ArrayList;
import java.util.List;


@Route("")
@SpringComponent
@UIScope
public class AddressUI extends HorizontalLayout implements AfterNavigationListener {

    private final Grid<Address> addressGrid;
    private final AddressRepository addressRepository;

    private Button saveButton;

    private Binder<Address> binder;


    public AddressUI(@Autowired AddressRepository addressRepository) {
        this.addressRepository = addressRepository;

        addressGrid = new Grid<>(Address.class);
        add(initForm());
        add(addressGrid);
        fillGrid();
    }

    private Component initForm() {

        binder = new Binder<>();

        FormLayout formLayout = new FormLayout();

        TextField nameField = new TextField();
        nameField.setLabel("Name");
        binder.forField(nameField)
                .bind(Address::getName, Address::setName);

        TextField vornameField = new TextField();
        vornameField.setLabel("Vorname");
        binder.forField(vornameField)
                .bind(Address::getVorname, Address::setVorname);

        TextField strasseField = new TextField();
        strasseField.setLabel("Strasse");
        binder.forField(strasseField)
                .bind(Address::getStrasse, Address::setStrasse);

        TextField plzField = new TextField();
        plzField.setLabel("PLZ");
        binder.forField(plzField)
                .bind(Address::getPlz, Address::setPlz);

        TextField stadtField = new TextField();
        stadtField.setLabel("Stadt");
        binder.forField(stadtField)
                .bind(Address::getStadt, Address::setStadt);


        saveButton = new Button("Save");
        saveButton.addClickListener((event) -> {
            Address s = new Address();
            binder.writeBeanIfValid(s);
            addressRepository.save(s);
            fillGrid();
        });

        formLayout.add(nameField, vornameField, strasseField, plzField, stadtField, saveButton);
        return formLayout;

    }


    private void fillGrid() {

        List<Address> addressList = new ArrayList<>();
        if (addressRepository != null) {
            addressRepository.findAll().forEach(addressList::add);
            addressGrid.setItems(addressList);
        }

    }


    @Override
    public void afterNavigation(AfterNavigationEvent afterNavigationEvent) {
        fillGrid();
    }
}
